#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

typedef NS_ENUM(NSInteger, LTState) {
    LTStateReset,
    LTStateRunning,
    LTStatePaused
};

static UIColor *LTColorForState(LTState st) {
    if (st == LTStateRunning) {
        return [UIColor colorWithRed:0.36
                               green:0.82
                                blue:0.42
                               alpha:1.0];
    }
    if (st == LTStatePaused) {
        return [UIColor colorWithRed:0.25
                               green:0.55
                                blue:0.95
                               alpha:1.0];
    }
    return [UIColor colorWithWhite:0.62 alpha:1.0];
}

@interface LTTimerView : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic) LTState state;
@property (nonatomic) CFTimeInterval startTime;
@property (nonatomic) CFTimeInterval accumulated;
@end

@implementation LTTimerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.92];
    self.layer.cornerRadius = 6;
    self.layer.masksToBounds = YES;

    CGRect lf = CGRectInset(self.bounds, 10, 0);
    self.label = [[UILabel alloc] initWithFrame:lf];
    self.label.textAlignment = NSTextAlignmentRight;
    self.label.adjustsFontSizeToFitWidth = YES;
    self.label.minimumScaleFactor = 0.6;
    [self addSubview:self.label];

    UITapGestureRecognizer *dbl =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(onDouble:)];
    dbl.numberOfTapsRequired = 2;
    [self addGestureRecognizer:dbl];

    UITapGestureRecognizer *one =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(onSingle:)];
    one.numberOfTapsRequired = 1;
    [self addGestureRecognizer:one];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(onPan:)];
    [self addGestureRecognizer:pan];

    CADisplayLink *link =
        [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    [link addToRunLoop:[NSRunLoop mainRunLoop]
               forMode:NSRunLoopCommonModes];

    [self refresh];
    return self;
}

- (CFTimeInterval)elapsed {
    if (self.state == LTStateRunning) {
        return self.accumulated + (CACurrentMediaTime() - self.startTime);
    }
    return self.accumulated;
}

- (void)onSingle:(UITapGestureRecognizer *)g {
    if (self.state == LTStateRunning) {
        self.accumulated += CACurrentMediaTime() - self.startTime;
        self.state = LTStatePaused;
    } else {
        self.startTime = CACurrentMediaTime();
        self.state = LTStateRunning;
    }
    [self refresh];
}

- (void)onDouble:(UITapGestureRecognizer *)g {
    self.state = LTStateReset;
    self.accumulated = 0;
    [self refresh];
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *host = self.superview;
    CGPoint t = [g translationInView:host];
    CGFloat x = self.center.x + t.x;
    CGFloat y = self.center.y + t.y;
    CGFloat hw = self.bounds.size.width / 2;
    CGFloat hh = self.bounds.size.height / 2;
    CGFloat maxX = host.bounds.size.width - hw;
    CGFloat maxY = host.bounds.size.height - hh;
    x = fmax(hw, fmin(x, maxX));
    y = fmax(hh, fmin(y, maxY));
    self.center = CGPointMake(x, y);
    [g setTranslation:CGPointZero inView:host];
}

- (void)tick {
    if (self.state == LTStateRunning) {
        [self refresh];
    }
}

- (void)refresh {
    CFTimeInterval e = [self elapsed];
    if (e < 0) e = 0;
    long long total = (long long)(e * 100.0);
    long long cs = total % 100;
    long long sec = total / 100;
    long long s = sec % 60;
    long long m = (sec / 60) % 60;
    long long h = sec / 3600;

    NSString *big;
    if (h > 0) {
        big = [NSString stringWithFormat:@"%lld:%02lld:%02lld", h, m, s];
    } else if (m > 0) {
        big = [NSString stringWithFormat:@"%lld:%02lld", m, s];
    } else {
        big = [NSString stringWithFormat:@"%lld", s];
    }
    NSString *small = [NSString stringWithFormat:@".%02lld", cs];

    UIColor *color = LTColorForState(self.state);
    UIFont *f1 = [UIFont monospacedDigitSystemFontOfSize:30
                                                  weight:UIFontWeightBold];
    UIFont *f2 = [UIFont monospacedDigitSystemFontOfSize:18
                                                  weight:UIFontWeightBold];
    NSDictionary *a1 = @{NSFontAttributeName: f1,
                         NSForegroundColorAttributeName: color};
    NSDictionary *a2 = @{NSFontAttributeName: f2,
                         NSForegroundColorAttributeName: color};

    NSMutableAttributedString *str =
        [[NSMutableAttributedString alloc] initWithString:big attributes:a1];
    NSAttributedString *tail =
        [[NSAttributedString alloc] initWithString:small attributes:a2];
    [str appendAttributedString:tail];
    self.label.attributedText = str;
}

@end

@interface LTWindow : UIWindow
@end

@implementation LTWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (v == self) return nil;
    if (v == self.rootViewController.view) return nil;
    return v;
}
@end

static LTWindow *gWindow;
static LTTimerView *gTimer;

static void LTInstall(void) {
    if (gWindow) return;

    CGRect screen = [UIScreen mainScreen].bounds;
    LTWindow *w = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if ([sc isKindOfClass:[UIWindowScene class]]) {
                w = [[LTWindow alloc] initWithWindowScene:(UIWindowScene *)sc];
                break;
            }
        }
    }
    if (!w) {
        w = [[LTWindow alloc] initWithFrame:screen];
    }

    w.frame = screen;
    w.windowLevel = UIWindowLevelAlert + 100;
    w.backgroundColor = [UIColor clearColor];

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    w.rootViewController = vc;

    CGRect frame = CGRectMake(16, 60, 130, 44);
    gTimer = [[LTTimerView alloc] initWithFrame:frame];
    [vc.view addSubview:gTimer];

    w.hidden = NO;
    gWindow = w;
}

__attribute__((constructor))
static void LTInit(void) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{ LTInstall(); });
    }];
}
