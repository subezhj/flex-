#import "UCLayoutDumpTool.h"
#import "FLEXDebugCapture.h"
#import "FLEXDebugExporter.h"
#import "FLEXCompatibility.h"
#import "FLEXColor.h"

@interface UCLayoutDumpPanelViewController : UIViewController
@property (nonatomic, copy) void (^onFullDump)(void);
@property (nonatomic, copy) void (^onLayoutOnlyDump)(void);
@property (nonatomic, copy) void (^onConfigOnlyDump)(void);
@property (nonatomic, copy) void (^onQuickScreenshot)(void);
@property (nonatomic, copy) void (^onOpenInFilza)(void);
@end

@implementation UCLayoutDumpPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSelf)];
    [self.view addGestureRecognizer:bgTap];
    
    [self setupGlassCard];
}

- (void)setupGlassCard {
    UIView *cardContainer = [UIView new];
    cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    cardContainer.layer.cornerRadius = 24.0;
    cardContainer.clipsToBounds = YES;
    cardContainer.layer.borderWidth = 0.5;
    cardContainer.layer.borderColor = [FLEXColor glassBorderColor].CGColor;
    
    cardContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    cardContainer.layer.shadowOpacity = 0.25;
    cardContainer.layer.shadowRadius = 16.0;
    cardContainer.layer.shadowOffset = CGSizeMake(0, 8);
    
    UIVisualEffectView *blurView = nil;
#if FLEX_AT_LEAST_IOS13_SDK
    if (@available(iOS 13.0, *)) {
        blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:FLEXBlurEffectStyleSystemThinMaterial]];
    }
#endif
    if (!blurView) {
        blurView = [UIVisualEffectView new];
        blurView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:0.95];
    }
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardContainer addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:cardContainer.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:cardContainer.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:cardContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:cardContainer.trailingAnchor]
    ]];
    
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cardContainer addSubview:stack];
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = @"📦 FLEX++ 布局与调试包导出";
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLabel.textColor = FLEXLabelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:titleLabel];
    
    UILabel *subLabel = [UILabel new];
    subLabel.text = @"支持一键抓取全量 UI 视图树、VC 堆栈、配置诊断、系统 Log 与网络请求。";
    subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    subLabel.textColor = FLEXSecondaryLabelColor;
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.numberOfLines = 0;
    [stack addArrangedSubview:subLabel];
    
    UIView *space = [UIView new];
    [space.heightAnchor constraintEqualToConstant:2].active = YES;
    [stack addArrangedSubview:space];
    
    UIButton *btnFull = [self createGlassButtonWithTitle:@"🚀 一键全量导出 ZIP (布局+配置+Log+网络)" isPrimary:YES action:@selector(btnFullTapped)];
    [stack addArrangedSubview:btnFull];
    
    UIButton *btnQuickPic = [self createGlassButtonWithTitle:@"📸 快捷导出当前画面截图 & 线框图 (PNG)" isPrimary:NO action:@selector(btnQuickPicTapped)];
    [stack addArrangedSubview:btnQuickPic];
    
    UIButton *btnLayout = [self createGlassButtonWithTitle:@"🎨 仅导出界面布局与视图树 (ViewTree+ZIP)" isPrimary:NO action:@selector(btnLayoutTapped)];
    [stack addArrangedSubview:btnLayout];
    
    UIButton *btnConfig = [self createGlassButtonWithTitle:@"⚙️ 仅导出配置诊断与环境问题" isPrimary:NO action:@selector(btnConfigTapped)];
    [stack addArrangedSubview:btnConfig];
    
    UIButton *btnFilza = [self createGlassButtonWithTitle:@"📂 在 Filza 中打开导出目录" isPrimary:NO action:@selector(btnFilzaTapped)];
    [stack addArrangedSubview:btnFilza];
    
    UIButton *btnCancel = [self createGlassButtonWithTitle:@"✕ 取消" isPrimary:NO action:@selector(dismissSelf)];
    [stack addArrangedSubview:btnCancel];
    
    [self.view addSubview:cardContainer];
    [NSLayoutConstraint activateConstraints:@[
        [cardContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [cardContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [cardContainer.widthAnchor constraintEqualToConstant:320.0],
        [stack.topAnchor constraintEqualToAnchor:cardContainer.topAnchor constant:18.0],
        [stack.bottomAnchor constraintEqualToAnchor:cardContainer.bottomAnchor constant:-18.0],
        [stack.leadingAnchor constraintEqualToAnchor:cardContainer.leadingAnchor constant:14.0],
        [stack.trailingAnchor constraintEqualToAnchor:cardContainer.trailingAnchor constant:-14.0]
    ]];
    
    cardContainer.transform = CGAffineTransformMakeScale(0.85, 0.85);
    cardContainer.alpha = 0.0;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        cardContainer.transform = CGAffineTransformIdentity;
        cardContainer.alpha = 1.0;
    } completion:nil];
}

- (UIButton *)createGlassButtonWithTitle:(NSString *)title isPrimary:(BOOL)isPrimary action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:isPrimary ? UIFontWeightBold : UIFontWeightMedium];
    [button setTitleColor:(isPrimary ? [UIColor systemBlueColor] : FLEXLabelColor) forState:UIControlStateNormal];
    button.backgroundColor = [FLEXColor glassCardBackgroundColor];
    button.layer.cornerRadius = 12.0;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [FLEXColor glassBorderColor].CGColor;
    button.clipsToBounds = YES;
    [button.heightAnchor constraintEqualToConstant:42.0].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)btnFullTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onFullDump) self.onFullDump();
    }];
}

- (void)btnQuickPicTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onQuickScreenshot) self.onQuickScreenshot();
    }];
}

- (void)btnLayoutTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onLayoutOnlyDump) self.onLayoutOnlyDump();
    }];
}

- (void)btnConfigTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onConfigOnlyDump) self.onConfigOnlyDump();
    }];
}

- (void)btnFilzaTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onOpenInFilza) self.onOpenInFilza();
    }];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation UCLayoutDumpTool

+ (void)presentDumpPanelFromViewController:(UIViewController *)viewController {
    UIViewController *presenter = viewController ?: [UIApplication sharedApplication].keyWindow.rootViewController;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    if (!presenter) return;
    
    UCLayoutDumpPanelViewController *panel = [UCLayoutDumpPanelViewController new];
    panel.modalPresentationStyle = UIModalPresentationOverFullScreen;
    panel.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    panel.onFullDump = ^{
        [self performFullLayoutDumpAndShareFromViewController:presenter];
    };
    panel.onQuickScreenshot = ^{
        [self performQuickScreenshotShareFromViewController:presenter];
    };
    panel.onLayoutOnlyDump = ^{
        [self performFullLayoutDumpAndShareFromViewController:presenter];
    };
    panel.onConfigOnlyDump = ^{
        [self performFullLayoutDumpAndShareFromViewController:presenter];
    };
    panel.onOpenInFilza = ^{
        NSURL *tmpURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        NSURL *filzaURL = [NSURL URLWithString:[NSString stringWithFormat:@"filza://%@", tmpURL.path]];
        if ([[UIApplication sharedApplication] canOpenURL:filzaURL]) {
            [[UIApplication sharedApplication] openURL:filzaURL options:@{} completionHandler:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未检测到 Filza" message:@"已在系统临时目录生成导出的调试包。你可以通过 AirDrop 或存储到文件访问该文件。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
        }
    };
    
    [presenter presentViewController:panel animated:YES completion:nil];
}

+ (void)performQuickScreenshotShareFromViewController:(UIViewController *)viewController {
    FLEXDebugCaptureContext *ctx = FLEXDebugCaptureCurrentContext();
    if (!ctx) return;
    
    NSMutableArray *items = [NSMutableArray array];
    if (ctx.screenshotImage) [items addObject:ctx.screenshotImage];
    if (ctx.wireframeImage) [items addObject:ctx.wireframeImage];
    
    if (items.count == 0) return;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = viewController.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(viewController.view.bounds.size.width / 2.0, viewController.view.bounds.size.height / 2.0, 1, 1);
    }
    [viewController presentViewController:activityVC animated:YES completion:nil];
}

+ (void)performFullLayoutDumpAndShareFromViewController:(UIViewController *)viewController {
    FLEXDebugCaptureContext *ctx = FLEXDebugCaptureCurrentContext();
    NSError *error = nil;
    FLEXDebugExportResult *result = FLEXDebugCreateExportPackage(ctx, &error);
    
    if (result && result.zipURL) {
        FLEXDebugPresentShareSheet(result, viewController);
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出失败" message:error.localizedDescription ?: @"未知原因" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [viewController presentViewController:alert animated:YES completion:nil];
    }
}

@end
