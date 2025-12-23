/*
 * IJKRTSPTestViewController.m
 * RTSP 录像测试页面 - 播放、快照、录像功能
 */

#import "IJKRTSPTestViewController.h"
#import <IJKMediaFramework/IJKMediaFramework.h>
#import <Photos/Photos.h>

@interface IJKRTSPTestViewController ()

@property (nonatomic, strong) IJKFFMoviePlayerController *player;
@property (nonatomic, strong) UIImageView *snapshotImageView;
@property (nonatomic, strong) UIButton *snapshotButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *rotateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSString *recordingPath;
@property (nonatomic, assign) NSInteger currentRotation; // 0, 90, 180, 270

@end

@implementation IJKRTSPTestViewController

+ (void)presentFrom:(UIViewController *)viewController {
    IJKRTSPTestViewController *vc = [[IJKRTSPTestViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [viewController presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.isRecording = NO;
    self.currentRotation = 0;
    
    [self setupPlayer];
    [self setupUI];
}

- (void)setupPlayer {
    // rtsp://192.168.2.23:8554/live  rtsp://192.168.1.1:7070/webcam
    NSURL *url = [NSURL URLWithString:@"rtsp://192.168.2.23:8554/live"];
    
    IJKFFOptions *options = [IJKFFOptions optionsByDefault];
    
    // // Player options
    // [options setPlayerOptionIntValue:0 forKey:@"mediacodec"];
    // [options setPlayerOptionIntValue:0 forKey:@"opensles"];
    // [options setPlayerOptionIntValue:0x32335652 forKey:@"overlay-format"];  // RV32
    // [options setPlayerOptionIntValue:1 forKey:@"framedrop"];
    // [options setPlayerOptionIntValue:0 forKey:@"start-on-prepared"];
    
    // // Format options
    // [options setFormatOptionIntValue:500000 forKey:@"initial_timeout"];
    // [options setFormatOptionIntValue:500000 forKey:@"stimeout"];
    // [options setFormatOptionIntValue:0 forKey:@"http-detect-range-support"];
    
    // // Codec options
    // [options setCodecOptionIntValue:48 forKey:@"skip_loop_filter"];
    
    // // Custom options - RTSP/MJPEG 相关
    // [options setPlayerOptionIntValue:1 forKey:@"rtp-jpeg-parse-packet-method"];
    // [options setPlayerOptionIntValue:25*1000*1000*3 forKey:@"readtimeout"];
    
    // // Image type
    // [options setPlayerOptionIntValue:0 forKey:@"preferred-image-type"];  // JPEG
    // [options setPlayerOptionIntValue:2 forKey:@"image-quality-min"];
    // [options setPlayerOptionIntValue:20 forKey:@"image-quality-max"];
    
    // // Video options
    // [options setPlayerOptionIntValue:2 forKey:@"preferred-video-type"];  // H264
    // [options setPlayerOptionIntValue:0 forKey:@"video-need-transcoding"];
    // [options setPlayerOptionIntValue:1 forKey:@"mjpeg-pix-fmt"];
    // [options setPlayerOptionIntValue:2 forKey:@"video-quality-min"];
    // [options setPlayerOptionIntValue:20 forKey:@"video-quality-max"];
    
    // // x264 options
    // [options setPlayerOptionIntValue:0 forKey:@"x264-option-preset"];  // ultrafast
    // [options setPlayerOptionIntValue:5 forKey:@"x264-option-tune"];    // zerolatency
    // [options setPlayerOptionIntValue:1 forKey:@"x264-option-profile"]; // main
    // [options setPlayerOptionValue:@"crf=20" forKey:@"x264-params"];


    #pragma mark - ========== Player ==========
    [options setPlayerOptionIntValue:0x36315652 forKey:@"overlay-format"]; // RV16
    [options setPlayerOptionIntValue:0 forKey:@"packet-buffering"];        // 强制无缓存播放
    [options setPlayerOptionIntValue:1 forKey:@"start-on-prepared"];       // 减少等待开始播放的时间
    [options setPlayerOptionIntValue:0 forKey:@"video-need-transcoding"];  // 关闭转码
    [options setPlayerOptionIntValue:1 forKey:@"videotoolbox"];            // iOS 硬件解码

    #pragma mark - ========== Format ==========
    [options setFormatOptionIntValue:100 forKey:@"analyzemaxduration"];    // 最长分析时长 (us)
    [options setFormatOptionIntValue:7168 forKey:@"probesize"];            // 读取数据包的最大缓冲区大小
    [options setFormatOptionIntValue:1 forKey:@"infbuf"];                  // 启用实时模式
    [options setFormatOptionIntValue:1 forKey:@"framedrop"];               // 启用丢帧
    [options setFormatOptionIntValue:500000 forKey:@"stimeout"];           // socket timeout
    [options setFormatOptionIntValue:0 forKey:@"http-detect-range-support"];

    #pragma mark - ========== Codec ==========
    [options setCodecOptionIntValue:48 forKey:@"skip_loop_filter"];        // 跳过滤波
    
    #pragma mark - ========== Other ==========
    [options setPlayerOptionIntValue:0 forKey:@"mediacodec"];              // iOS 不用
    [options setPlayerOptionIntValue:0 forKey:@"opensles"];                // iOS 不用

    
    self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:url withOptions:options];
    self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.player.view.frame = self.view.bounds;
    self.player.scalingMode = IJKMPMovieScalingModeAspectFit;
    self.player.shouldAutoplay = YES;
    
    // 确保 player view 在最底层
    [self.view insertSubview:self.player.view atIndex:0];
}

- (void)setupUI {
    // 关闭按钮
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(20, 50, 60, 40);
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.6];
    self.closeButton.layer.cornerRadius = 8;
    [self.closeButton addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(90, 50, 200, 40)];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.text = @"准备中...";
    [self.view addSubview:self.statusLabel];
    
    // 底部按钮容器
    CGFloat buttonWidth = 90;
    CGFloat buttonHeight = 50;
    CGFloat bottomMargin = 50;
    CGFloat spacing = 15;
    CGFloat totalWidth = buttonWidth * 3 + spacing * 2;
    CGFloat startX = (self.view.bounds.size.width - totalWidth) / 2;
    CGFloat buttonY = self.view.bounds.size.height - bottomMargin - buttonHeight;
    
    // 快照按钮
    self.snapshotButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.snapshotButton.frame = CGRectMake(startX, buttonY, buttonWidth, buttonHeight);
    [self.snapshotButton setTitle:@"📷 快照" forState:UIControlStateNormal];
    [self.snapshotButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.snapshotButton.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
    self.snapshotButton.layer.cornerRadius = 10;
    self.snapshotButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.snapshotButton addTarget:self action:@selector(onSnapshot) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.snapshotButton];
    
    // 录像按钮
    self.recordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.recordButton.frame = CGRectMake(startX + buttonWidth + spacing, buttonY, buttonWidth, buttonHeight);
    [self.recordButton setTitle:@"🔴 录像" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.recordButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
    self.recordButton.layer.cornerRadius = 10;
    self.recordButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.recordButton addTarget:self action:@selector(onRecord) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.recordButton];
    
    // 旋转按钮
    self.rotateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.rotateButton.frame = CGRectMake(startX + (buttonWidth + spacing) * 2, buttonY, buttonWidth, buttonHeight);
    [self.rotateButton setTitle:@"🔄 旋转" forState:UIControlStateNormal];
    [self.rotateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.rotateButton.backgroundColor = [[UIColor purpleColor] colorWithAlphaComponent:0.7];
    self.rotateButton.layer.cornerRadius = 10;
    self.rotateButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.rotateButton addTarget:self action:@selector(onRotate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.rotateButton];
    
    // 快照预览 ImageView（右上角小图）
    CGFloat previewSize = 150;
    self.snapshotImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - previewSize - 20, 50, previewSize, previewSize * 9 / 16)];
    self.snapshotImageView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.snapshotImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.snapshotImageView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.snapshotImageView.layer.borderWidth = 1;
    self.snapshotImageView.layer.cornerRadius = 8;
    self.snapshotImageView.clipsToBounds = YES;
    self.snapshotImageView.hidden = YES;
    [self.view addSubview:self.snapshotImageView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerPrepared:)
                                                 name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:self.player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerStateChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:self.player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerFinish:)
                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                               object:self.player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onLoadStateChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:self.player];
    
    NSLog(@"RTSP Test: prepareToPlay");
    [self.player prepareToPlay];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // 停止录像
    if (self.isRecording) {
        [self.player stopRecording];
    }
    
    [self.player shutdown];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)onClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/**
 * 旋转视频，循环切换 0 -> 90 -> 180 -> 270 -> 0
 * 横屏(0°/180°)时全屏显示，竖屏(90°/270°)时 4:3 自适应
 */
- (void)onRotate {
    self.currentRotation = (self.currentRotation + 90) % 360;
    
    // 应用旋转
    CGAffineTransform transform = CGAffineTransformMakeRotation(self.currentRotation * M_PI / 180.0);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.player.view.transform = transform;
        
        // 根据旋转角度调整画面显示模式
        // 0° 或 180° 是横屏 -> 全屏填充
        // 90° 或 270° 是竖屏 -> 4:3 自适应
        if (self.currentRotation == 0 || self.currentRotation == 180) {
            // 横屏：全屏填充
            self.player.view.frame = self.view.bounds;
            self.player.scalingMode = IJKMPMovieScalingModeAspectFill;
            self.statusLabel.text = [NSString stringWithFormat:@"🔄 旋转: %ld° (全屏)", (long)self.currentRotation];
        } else {
            // 竖屏：4:3 自适应
            CGFloat width = self.view.bounds.size.height;  // 旋转后宽高交换
            CGFloat height = self.view.bounds.size.width;
            self.player.view.frame = CGRectMake(
                (self.view.bounds.size.width - height) / 2,
                (self.view.bounds.size.height - width) / 2,
                height,
                width
            );
            self.player.scalingMode = IJKMPMovieScalingModeAspectFit;
            self.statusLabel.text = [NSString stringWithFormat:@"🔄 旋转: %ld° (自适应)", (long)self.currentRotation];
        }
    }];
}

- (void)onSnapshot {
    // 使用 thumbnailImageAtCurrentTime 方法获取快照
    UIImage *snapshot = [self.player thumbnailImageAtCurrentTime];
    
    if (snapshot) {
        self.snapshotImageView.image = snapshot;
        self.snapshotImageView.hidden = NO;
        self.statusLabel.text = @"✅ 快照成功";
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(snapshot, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    } else {
        self.statusLabel.text = @"❌ 快照失败";
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        self.statusLabel.text = @"保存相册失败";
    } else {
        self.statusLabel.text = @"✅ 已保存到相册";
    }
}

- (void)onRecord {
    if (!self.isRecording) {
        // 开始录像
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
        NSString *filename = [NSString stringWithFormat:@"record_%@.mp4", [formatter stringFromDate:[NSDate date]]];
        self.recordingPath = [documentsPath stringByAppendingPathComponent:filename];
        
        int result = [self.player startRecording:self.recordingPath];
        if (result == 0) {
            self.isRecording = YES;
            [self.recordButton setTitle:@"⏹ 停止" forState:UIControlStateNormal];
            self.recordButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.9];
            self.statusLabel.text = @"🔴 录像中...";
        } else {
            self.statusLabel.text = @"❌ 开始录像失败";
        }
    } else {
        // 停止录像
        int result = [self.player stopRecording];
        if (result == 0) {
            self.isRecording = NO;
            [self.recordButton setTitle:@"🔴 录像" forState:UIControlStateNormal];
            self.recordButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
            self.statusLabel.text = @"正在保存到相册...";
            
            // 保存视频到相册
            [self saveVideoToAlbum:self.recordingPath];
        } else {
            self.statusLabel.text = @"❌ 停止录像失败";
        }
    }
}

- (void)saveVideoToAlbum:(NSString *)videoPath {
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        self.statusLabel.text = [NSString stringWithFormat:@"✅ 已保存到相册: %@", [videoPath lastPathComponent]];
                    } else {
                        self.statusLabel.text = [NSString stringWithFormat:@"保存相册失败: %@", error.localizedDescription];
                    }
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"❌ 无相册权限";
            });
        }
    }];
}

#pragma mark - Notifications

- (void)onPlayerPrepared:(NSNotification *)notification {
    self.statusLabel.text = @"▶️ 正在播放";
}

- (void)onPlayerStateChange:(NSNotification *)notification {
    NSLog(@"RTSP Test: playbackState = %ld", (long)self.player.playbackState);
    switch (self.player.playbackState) {
        case IJKMPMoviePlaybackStatePlaying:
            self.statusLabel.text = @"▶️ 正在播放";
            break;
        case IJKMPMoviePlaybackStatePaused:
            self.statusLabel.text = @"⏸ 已暂停";
            break;
        case IJKMPMoviePlaybackStateStopped:
            self.statusLabel.text = @"⏹ 已停止";
            break;
        default:
            break;
    }
}

- (void)onPlayerFinish:(NSNotification *)notification {
    int reason = [[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    NSLog(@"RTSP Test: playback finished, reason = %d", reason);
    
    switch (reason) {
        case IJKMPMovieFinishReasonPlaybackEnded:
            self.statusLabel.text = @"播放结束";
            break;
        case IJKMPMovieFinishReasonPlaybackError:
            self.statusLabel.text = @"❌ 播放错误 - 检查RTSP地址";
            break;
        case IJKMPMovieFinishReasonUserExited:
            self.statusLabel.text = @"用户退出";
            break;
        default:
            break;
    }
}

- (void)onLoadStateChange:(NSNotification *)notification {
    IJKMPMovieLoadState loadState = self.player.loadState;
    NSLog(@"RTSP Test: loadState = %lu", (unsigned long)loadState);
    
    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {
        self.statusLabel.text = @"▶️ 缓冲完成";
    } else if ((loadState & IJKMPMovieLoadStateStalled) != 0) {
        self.statusLabel.text = @"⏳ 缓冲中...";
    } else if ((loadState & IJKMPMovieLoadStatePlayable) != 0) {
        self.statusLabel.text = @"可播放";
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end
