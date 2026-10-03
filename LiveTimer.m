// LiveTimer.m - cronômetro overlay estilo LiveSplit para iOS
//
// 1 toque = inicia / para (pausa)
// 2 toques = reinicia
// Arrastar = move o cronômetro de lugar
//
// Cores: verde = rodando | azul = pausado | cinza = reiniciado
//
// Compilar (no Mac, com Xcode):
// // xcrun -sdk iphoneos clang -dynamiclib -arch arm64 -fobjc-arc \
// -miphoneos-version-min=12.0 \
-framework UIKit -framework Foundation -framework QuartzCore \
// -o LiveTimer.dylib LiveTimer.m
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
typedef NS_ENUM(NSInteger, LTState) {
LTStateReset,
LTStateRunning,
LTStatePaused
};
// ---------- Aparência (mude aqui) ----------
static const CGFloat kBigFont = 30.0; // segundos / minutos
static const CGFloat kSmallFont = 18.0; // centésimos
static const CGFloat kPadding = 10.0;
static const CGFloat kWidth = 130.0;
static const CGFloat kHeight = 44.0;
static UIColor *ColorGreen(void) { return [UIColor colorWithRed:0.36 green:0.82 blue:0.42 alp
static UIColor *ColorBlue(void) { return [UIColor colorWithRed:0.25 green:0.55 blue:0.95 alp
static UIColor *ColorGray(void) { return [UIColor colorWithWhite:0.62 alpha:1.0]; }
// ---------- View do cronômetro ----------
@interface LTTimerView : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) LTState state;
@property (nonatomic) CFTimeInterval startTime; // instante em que começou o trecho atual
@property (nonatomic) CFTimeInterval accumulated; // tempo acumulado antes do trecho atual
@end
@implementation LTTimerView
- (instancetype)initWithFrame:(CGRect)frame {
if ((self = [super initWithFrame:frame])) {
self.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.06 alpha:0.92];
self.layer.cornerRadius = 6;
self.layer.masksToBounds = YES;
self.multipleTouchEnabled = NO;
_label = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, kPadding, 0)];
_label.textAlignment = NSTextAlignmentRight;
_label.adjustsFontSizeToFitWidth = YES;
_label.minimumScaleFactor = 0.6;
_label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibl
[self addSubview:_label];
// Dois toques (reinicia) e um toque (inicia/para).
// Sem requireGestureRecognizerToFail: o 1º toque age na hora (sem atraso);
// no 2º toque o duplo-toque reinicia tudo.
UITapGestureRecognizer *doubleTap =
[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:
doubleTap.numberOfTapsRequired = 2;
[self addGestureRecognizer:doubleTap];
UITapGestureRecognizer *singleTap =
[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSingleTap:
singleTap.numberOfTapsRequired = 1;
[self addGestureRecognizer:singleTap];
UIPanGestureRecognizer *pan =
[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
pan.maximumNumberOfTouches = 1;
[self addGestureRecognizer:pan];
_link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
[_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
[self refresh];
}
return self;
}
- (CFTimeInterval)elapsed {
if (self.state == LTStateRunning) {
return self.accumulated + (CACurrentMediaTime() - self.startTime);
}
return self.accumulated;
}
// ---------- Ações ----------
- (void)onSingleTap:(UITapGestureRecognizer *)g {
if (self.state == LTStateRunning) {
self.accumulated += CACurrentMediaTime() - self.startTime;
self.state = LTStatePaused;
} else {
// Reset ou Pausado -> roda (retoma de onde parou)
self.startTime = CACurrentMediaTime();
self.state = LTStateRunning;
}
[self refresh];
}
- (void)onDoubleTap:(UITapGestureRecognizer *)g {
self.state = LTStateReset;
self.accumulated = 0;
[self refresh];
}
- (void)onPan:(UIPanGestureRecognizer *)g {
UIView *host = self.superview;
CGPoint t = [g translationInView:host];
CGPoint c = CGPointMake(self.center.x + t.x, self.center.y + t.y);
CGRect b = host.bounds;
c.x = MAX(CGRectGetWidth(self.bounds) / 2, MIN(c.x, CGRectGetWidth(b) - CGRectGetWidth(se
c.y = MAX(CGRectGetHeight(self.bounds) / 2, MIN(c.y, CGRectGetHeight(b) - CGRectGetHeight
self.center = c;
[g setTranslation:CGPointZero inView:host];
}
// ---------- Exibição ----------
- (void)tick {
if (self.state == LTStateRunning) [self refresh];
}
- (UIColor *)currentColor {
switch (self.state) {
case LTStateRunning: return ColorGreen();
case LTStatePaused: return ColorBlue();
default: return ColorGray();
}
}
// Formato LiveSplit: 23.57 | 1:23.57 | 1:02:03.45
- (void)refresh {
CFTimeInterval e = [self elapsed];
if (e < 0) e = 0;
long long totalCs = (long long)(e * 100.0);
long long cs = totalCs % 100;
long long totalSec = totalCs / 100;
long long s = totalSec % 60;
long long m = (totalSec / 60) % 60;
long long h = totalSec / 3600;
NSString *big;
if (h > 0) big = [NSString stringWithFormat:@"%lld:%02lld:%02lld", h, m, s];
else if (m > 0) big = [NSString stringWithFormat:@"%lld:%02lld", m, s];
else big = [NSString stringWithFormat:@"%lld", s];
NSString *small = [NSString stringWithFormat:@".%02lld", cs];
UIColor *color = [self currentColor];
UIFont *bigFont = [UIFont systemFontOfSize:kBigFont weight:UIFontWeightBold];
UIFont *smallFont = [UIFont systemFontOfSize:kSmallFont weight:UIFontWeightBold];
// Algarismos de largura fixa para o texto não "tremer" ao contar
bigFont = [UIFont monospacedDigitSystemFontOfSize:kBigFont weight:UIFontWeightBold];
smallFont = [UIFont monospacedDigitSystemFontOfSize:kSmallFont weight:UIFontWeightBold];
NSMutableAttributedString *str = [[NSMutableAttributedString alloc]
initWithString:big attributes:@{NSFontAttributeName: bigFont,
NSForegroundColorAttributeName: color}];
[str appendAttributedString:[[NSAttributedString alloc]
initWithString:small attributes:@{NSFontAttributeName: smallFont,
NSForegroundColorAttributeName: color}]];
self.label.attributedText = str;
}
@end
// ---------- Janela overlay ----------
static UIWindow *gWindow;
static LTTimerView *gTimer;
static UIWindowScene *FindActiveScene(void) {
if (@available(iOS 13.0, *)) {
for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
if ([sc isKindOfClass:[UIWindowScene class]] &&
sc.activationState == UISceneActivationStateForegroundActive) {
return (UIWindowScene *)sc;
}
}
for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
if ([sc isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)sc;
}
}
return nil;
}
// Janela que só captura toque dentro do cronômetro; o resto passa para o jogo.
@interface LTPassthroughWindow : UIWindow
@end
@implementation LTPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
UIView *v = [super hitTest:point withEvent:event];
return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end
static void InstallOverlay(void) {
if (gWindow) return;
CGRect screen = UIScreen.mainScreen.bounds;
LTPassthroughWindow *w;
if (@available(iOS 13.0, *)) {
UIWindowScene *scene = FindActiveScene();
if (scene) w = [[LTPassthroughWindow alloc] initWithWindowScene:scene];
}
if (!w) w = [[LTPassthroughWindow alloc] initWithFrame:screen];
w.frame = screen;
w.windowLevel = UIWindowLevelAlert + 100;
w.backgroundColor = UIColor.clearColor;
UIViewController *vc = [UIViewController new];
vc.view.backgroundColor = UIColor.clearColor;
w.rootViewController = vc;
CGFloat top = 60; // abaixo do notch / ilha
if (@available(iOS 11.0, *)) top = MAX(top, w.safeAreaInsets.top + 12);
gTimer = [[LTTimerView alloc] initWithFrame:CGRectMake(16, top, kWidth, kHeight)];
[vc.view addSubview:gTimer];
w.hidden = NO;
gWindow = w;
}
__attribute__((constructor))
static void LiveTimerInit(void) {
// Espera o app ficar ativo (a janela do jogo já existe nesse ponto)
[[NSNotificationCenter defaultCenter]
addObserverForName:UIApplicationDidBecomeActiveNotification
object:nil
queue:NSOperationQueue.mainQueue
usingBlock:^(NSNotification *n) {
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
dispatch_get_main_queue(), ^{ InstallOverlay(); }); }];
}
