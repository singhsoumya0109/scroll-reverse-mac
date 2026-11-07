#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@property (nonatomic, assign) CFMachPortRef machPort;
@property (nonatomic, assign) CFRunLoopSourceRef runLoopSource;
@property (nonatomic, strong) NSTimer *permissionTimer;

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL reverseVertical;
@property (nonatomic, assign) BOOL reverseHorizontal;
@property (nonatomic, assign) BOOL startAtLogin;

@end

// Global pointer to the active delegate for the C-callback
static __weak AppDelegate *g_appDelegate = nil;

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    AppDelegate *delegate = g_appDelegate;
    if (!delegate) {
        return event;
    }

    // Recover if tap was disabled by macOS due to timeout or user input load
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (delegate.machPort) {
            CGEventTapEnable(delegate.machPort, true);
        }
        return event;
    }

    if (type != kCGEventScrollWheel || !delegate.isEnabled) {
        return event;
    }

    // Identify device type:
    // Trackpads and continuous devices (e.g. Magic Mouse, trackpad gestures) emit continuous scroll events
    // Traditional mouse scroll wheels emit discrete scroll events (kCGScrollWheelEventIsContinuous == 0).
    int64_t isContinuous = CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    if (isContinuous != 0) {
        // Trackpad event: Leave natural scrolling untouched!
        return event;
    }

    // Physical mouse wheel event: Invert according to settings
    if (delegate.reverseVertical) {
        int64_t deltaY = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
        int64_t pointDeltaY = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
        double fixedDeltaY = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);

        CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -deltaY);
        if (pointDeltaY != 0) {
            CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pointDeltaY);
        }
        if (fixedDeltaY != 0.0) {
            CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -fixedDeltaY);
        }
    }

    if (delegate.reverseHorizontal) {
        int64_t deltaX = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
        int64_t pointDeltaX = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
        double fixedDeltaX = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);

        CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -deltaX);
        if (pointDeltaX != 0) {
            CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pointDeltaX);
        }
        if (fixedDeltaX != 0.0) {
            CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -fixedDeltaX);
        }
    }

    return event;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    g_appDelegate = self;

    // Load preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        @"IsEnabled": @YES,
        @"ReverseVertical": @YES,
        @"ReverseHorizontal": @NO,
        @"StartAtLogin": @NO
    }];

    self.isEnabled = [defaults boolForKey:@"IsEnabled"];
    self.reverseVertical = [defaults boolForKey:@"ReverseVertical"];
    self.reverseHorizontal = [defaults boolForKey:@"ReverseHorizontal"];
    self.startAtLogin = [self isLaunchAgentInstalled];

    [self setupMenuBar];
    [self startEventTapOrPrompt];
}

#pragma mark - Menu Bar Setup

- (NSImage *)createMouseIcon {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [[NSColor labelColor] setStroke];
        [[NSColor labelColor] setFill];

        // Mouse body outline
        NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3.5, 1.5, 11, 15) xRadius:5 yRadius:5];
        [body setLineWidth:1.5];
        [body stroke];

        // Center scroll wheel
        NSBezierPath *wheel = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(7.5, 8.5, 3, 5) xRadius:1.5 yRadius:1.5];
        [wheel fill];

        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

- (void)setupMenuBar {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [self createMouseIcon];
    self.statusItem.button.toolTip = @"Scroll Reverse";

    self.menu = [[NSMenu alloc] initWithTitle:@"Scroll Reverse"];
    self.menu.delegate = self;
    self.statusItem.menu = self.menu;
    [self updateMenu];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateMenu];
}

- (void)updateMenu {
    [self.menu removeAllItems];

    // Title / Status item
    BOOL trusted = AXIsProcessTrusted();
    NSString *statusText = @"Status: Disabled";
    if (!trusted) {
        statusText = @"Status: ⚠️ Accessibility Required";
    } else if (self.isEnabled) {
        statusText = @"Status: ● Active (Mouse Inverted)";
    }

    NSMenuItem *statusItem = [[NSMenuItem alloc] initWithTitle:statusText action:nil keyEquivalent:@""];
    [statusItem setEnabled:NO];
    [self.menu addItem:statusItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    // Active Toggle
    NSMenuItem *enableItem = [[NSMenuItem alloc] initWithTitle:@"Enable Scroll Reversal" action:@selector(toggleEnabled:) keyEquivalent:@""];
    [enableItem setState:self.isEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    [self.menu addItem:enableItem];

    // Reverse Vertical Toggle
    NSMenuItem *vertItem = [[NSMenuItem alloc] initWithTitle:@"Reverse Vertical Scroll (Wheel)" action:@selector(toggleVertical:) keyEquivalent:@""];
    [vertItem setState:self.reverseVertical ? NSControlStateValueOn : NSControlStateValueOff];
    [self.menu addItem:vertItem];

    // Reverse Horizontal Toggle
    NSMenuItem *horizItem = [[NSMenuItem alloc] initWithTitle:@"Reverse Horizontal Scroll (Wheel)" action:@selector(toggleHorizontal:) keyEquivalent:@""];
    [horizItem setState:self.reverseHorizontal ? NSControlStateValueOn : NSControlStateValueOff];
    [self.menu addItem:horizItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    // Start at login
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Start at Login" action:@selector(toggleStartAtLogin:) keyEquivalent:@""];
    [loginItem setState:self.startAtLogin ? NSControlStateValueOn : NSControlStateValueOff];
    [self.menu addItem:loginItem];

    // Accessibility settings helper
    if (!trusted) {
        NSMenuItem *axItem = [[NSMenuItem alloc] initWithTitle:@"Open Accessibility Settings..." action:@selector(openAccessibilitySettings:) keyEquivalent:@""];
        [self.menu addItem:axItem];
    }

    [self.menu addItem:[NSMenuItem separatorItem]];

    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Scroll Reverse" action:@selector(terminate:) keyEquivalent:@"q"];
    [quitItem setTarget:NSApp];
    [self.menu addItem:quitItem];
}

#pragma mark - Event Tap Management

- (void)startEventTapOrPrompt {
    if (self.machPort != NULL) {
        return; // Already running
    }

    // Check accessibility permissions
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);

    if (!trusted) {
        NSLog(@"[ScrollReverse] Accessibility permissions not yet granted. Waiting...");
        // Poll every 1.5 seconds so as soon as user enables it in Settings, it activates automatically
        if (!self.permissionTimer) {
            self.permissionTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
                if (AXIsProcessTrusted()) {
                    NSLog(@"[ScrollReverse] Accessibility permissions granted!");
                    [timer invalidate];
                    self.permissionTimer = nil;
                    [self createEventTap];
                    [self updateMenu];
                }
            }];
        }
        return;
    }

    [self createEventTap];
}

- (void)createEventTap {
    if (self.machPort != NULL) {
        return;
    }

    CGEventMask eventMask = CGEventMaskBit(kCGEventScrollWheel);
    self.machPort = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        eventMask,
        eventTapCallback,
        (__bridge void *)self
    );

    if (!self.machPort) {
        NSLog(@"[ScrollReverse] Failed to create CGEventTap. Please verify Accessibility permissions.");
        return;
    }

    self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.machPort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), self.runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(self.machPort, true);
    NSLog(@"[ScrollReverse] Successfully hooked into scroll wheel events.");
}

- (void)destroyEventTap {
    if (self.machPort != NULL) {
        CGEventTapEnable(self.machPort, false);
        if (self.runLoopSource != NULL) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), self.runLoopSource, kCFRunLoopCommonModes);
            CFRelease(self.runLoopSource);
            self.runLoopSource = NULL;
        }
        CFRelease(self.machPort);
        self.machPort = NULL;
    }
}

#pragma mark - Actions

- (void)toggleEnabled:(id)sender {
    self.isEnabled = !self.isEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:self.isEnabled forKey:@"IsEnabled"];
    [self updateMenu];
}

- (void)toggleVertical:(id)sender {
    self.reverseVertical = !self.reverseVertical;
    [[NSUserDefaults standardUserDefaults] setBool:self.reverseVertical forKey:@"ReverseVertical"];
    [self updateMenu];
}

- (void)toggleHorizontal:(id)sender {
    self.reverseHorizontal = !self.reverseHorizontal;
    [[NSUserDefaults standardUserDefaults] setBool:self.reverseHorizontal forKey:@"ReverseHorizontal"];
    [self updateMenu];
}

- (void)openAccessibilitySettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - Launch at Login Management

- (NSString *)launchAgentPlistPath {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@"Library/LaunchAgents/com.local.scrollreverse.plist"];
}

- (BOOL)isLaunchAgentInstalled {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self launchAgentPlistPath]];
}

- (void)toggleStartAtLogin:(id)sender {
    self.startAtLogin = !self.startAtLogin;
    NSString *plistPath = [self launchAgentPlistPath];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (self.startAtLogin) {
        NSString *execPath = [[NSBundle mainBundle] executablePath];
        if (!execPath) {
            execPath = [[NSBundle mainBundle] bundlePath];
        }

        NSDictionary *plistDict = @{
            @"Label": @"com.local.scrollreverse",
            @"ProgramArguments": @[execPath],
            @"RunAtLoad": @YES,
            @"KeepAlive": @NO,
            @"ProcessType": @"Interactive"
        };

        NSString *dir = [plistPath stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [plistDict writeToFile:plistPath atomically:YES];
        NSLog(@"[ScrollReverse] Installed LaunchAgent at %@", plistPath);
    } else {
        [fm removeItemAtPath:plistPath error:nil];
        NSLog(@"[ScrollReverse] Removed LaunchAgent from %@", plistPath);
    }

    [[NSUserDefaults standardUserDefaults] setBool:self.startAtLogin forKey:@"StartAtLogin"];
    [self updateMenu];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self destroyEventTap];
    if (self.permissionTimer) {
        [self.permissionTimer invalidate];
        self.permissionTimer = nil;
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Prevent duplicate instances
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
            if ([apps count] > 1) {
                NSLog(@"[ScrollReverse] Already running. Exiting.");
                return 0;
            }
        }

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; // Menu bar only (no dock icon)

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
