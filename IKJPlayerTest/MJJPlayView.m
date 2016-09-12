//
//  MJJPlayView.m
//  IKJPlayerTest
//
//  Created by majunjie on 16/9/9.
//  Copyright © 2016年 majunjie. All rights reserved.
//
#define TOOLCOLOR [UIColor colorWithRed:0 green:100 blue:0 alpha:0.3]
#import "MJJPlayView.h"
#import "UIView+SCYCategory.h"
#import "UIDevice+XJDevice.h"
#import "XJGestureButton.h"

#define WS(weakSelf) __unsafe_unretained __typeof(&*self)weakSelf = self;

typedef NS_ENUM(NSUInteger, Direction) {
    DirectionLeftOrRight,
    DirectionUpOrDown,
    DirectionNone
};


@interface MJJPlayView ()<UIGestureRecognizerDelegate,XJGestureButtonDelegate>
{
    UIView *_playerView;
    UIView *_toolView;
    BOOL isHiden;//底部菜单是否收起
    BOOL isPlay;//是否播放
    BOOL isFull;//是否全屏
    BOOL isFirst;//是否第一次加载
    BOOL isAutoOrient;//自动旋转（不是用放大按钮）
    CGRect xjPlayerFrame;//自定义的视屏大小
    CMTime ALLduration; //视频总时长
    BOOL _isMediaSliderBeingDragged;//当前进度条状态
    
}

@property(atomic, retain) id<IJKMediaPlayback> IKJplayer;

@property (nonatomic, strong) UIView *bottomMenuView;//底部菜单
@property (nonatomic, strong) UIButton *playOrPauseBtn;//开始/暂停按钮
@property (nonatomic, strong) UIButton *nextPlayerBtn;//下一个视屏
@property (nonatomic, strong) UIProgressView *loadProgressView;//缓冲进度条
@property (nonatomic, strong) UISlider *playSlider;//播放滑动条
@property (nonatomic, strong) UIButton *fullOrSmallBtn;//放大/缩小按钮
@property (nonatomic, strong) UILabel *timeLabel;//时间标签
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;//菊花图
@property (nonatomic, strong) id playbackTimeObserver;//界面更新时间ID
@property (nonatomic, strong) NSString *avTotalTime;//视屏时间总长；
@property (assign, nonatomic) Direction direction;
@property (assign, nonatomic) CGPoint startPoint;//手势触摸起始位置
@property (assign, nonatomic) CGFloat startVB;//记录当前音量/亮度
@property (assign, nonatomic) CGFloat startVideoRate;//开始进度
@property (strong, nonatomic) CADisplayLink *link;
@property (assign, nonatomic) NSTimeInterval lastTime;
@property (strong, nonatomic) MPVolumeView *volumeView;//控制音量的view
@property (strong, nonatomic) UISlider *volumeViewSlider;//控制音量
@property (assign, nonatomic) CGFloat currentRate;//当期视频播放的进度

@end
@implementation MJJPlayView

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
       self.backgroundColor = [UIColor clearColor];
        [self setUserInteractionEnabled:NO];
        xjPlayerFrame = frame;
        [self installMovieNotificationObservers];

    }
    return self;
}

#pragma mark - 初始化播放器
- (void)MJJPlayerInit{
    //限制锁屏
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    
    if (self.IKJplayer) {
        self.IKJplayer = nil;
    }
    
    self.IKJplayer = [[IJKFFMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:self.MJJPlayerUrl]
                                                         withOptions:nil];
    _playerView= [_IKJplayer view];
    _playerView.frame = self.bounds;
    _playerView.autoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_playerView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientChange:) name:UIDeviceOrientationDidChangeNotification object:nil];//注册监听，屏幕方向改变
}

-(void)addToolView{
    
//    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(upadte)];//和屏幕频率刷新相同的定时器
//    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.xjGestureButton addSubview:self.bottomMenuView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    tap.cancelsTouchesInView = NO;
    [self.bottomMenuView addGestureRecognizer:tap];//防止bottomMenuView也响应了self这个view的单击手势
    [self addSubview:self.xjGestureButton];
    [self.bottomMenuView addSubview:self.playOrPauseBtn];
    [self.bottomMenuView addSubview:self.nextPlayerBtn];
    [self.bottomMenuView addSubview:self.fullOrSmallBtn];
    [self.bottomMenuView addSubview:self.timeLabel];
    [self.bottomMenuView addSubview:self.loadProgressView];
    [self.bottomMenuView addSubview:self.playSlider];
    [self addSubview:self.loadingView];
}

#pragma mark - 单击隐藏或者展开底部菜单
- (void)showOrHidenMenuView{
    if (isHiden) {
         [self performSelector:@selector(hideToolView) withObject:nil afterDelay:5];
        [UIView animateWithDuration:0.3 animations:^{
            self.bottomMenuView.hidden  = NO;
            [self getMediaInfo];
            isHiden = NO;
        }];
    }else{
        //[self cancelDelayedHide];
        [UIView animateWithDuration:0.3 animations:^{
            self.bottomMenuView.hidden  = YES;
            isHiden = YES;
        }];
    }
}

- (void)hideToolView
{
    self.bottomMenuView.hidden = YES;
    [self cancelDelayedHide];
}

- (void)cancelDelayedHide
{
    isHiden=YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideToolView) object:nil];
}

#pragma mark - 控件事件
//开始/暂停视频播放
- (void)playOrPauseAction{
    if (!isPlay) {
        [self.IKJplayer play];
        isPlay = YES;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        if ([self.delegate respondsToSelector:@selector(xjPlayerPlayOrPause:)]) {
            [self.delegate xjPlayerPlayOrPause:NO];
        }
    }else{
        [self.IKJplayer pause];
        isPlay = NO;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        if ([self.delegate respondsToSelector:@selector(xjPlayerPlayOrPause:)]) {
            [self.delegate xjPlayerPlayOrPause:YES];
        }
    }
}
//下一个视频
- (void)nextPlayerAction{
    if ([self.delegate respondsToSelector:@selector(nextXJPlayer)]) {
        [self.delegate nextXJPlayer];
    }
}
//放大/缩小视图
- (void)fullOrSmallAction{
    if (isFull) {
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationPortrait];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        self.frame = xjPlayerFrame;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
        if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
            [self.delegate xjPlayerFullOrSmall:NO];
        }
    }else{
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationLandscapeRight];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        self.frame = self.window.bounds;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
        isFull = YES;
        if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
            [self.delegate xjPlayerFullOrSmall:YES];
        }
    }
}

- (void)didSliderTouchDown
{
    _isMediaSliderBeingDragged = YES;
}

- (void)didSliderTouchCancel
{
    _isMediaSliderBeingDragged = NO;
}

- (void)didSliderTouchUpOutside
{
     _isMediaSliderBeingDragged = NO;
}

- (void)didSliderTouchUpInside
{
    _IKJplayer.currentPlaybackTime = self.playSlider.value;
    _isMediaSliderBeingDragged = NO;
}

- (void)didSliderValueChanged
{
    [self.loadingView startAnimating];
    [self getMediaInfo];
}


#pragma mark - 自定义Button的代理***********************************************************
#pragma mark - 开始触摸
/*************************************************************************/
- (void)touchesBeganWithPoint:(CGPoint)point {
    //记录首次触摸坐标
    self.startPoint = point;
    //检测用户是触摸屏幕的左边还是右边，以此判断用户是要调节音量还是亮度，左边是音量，右边是亮度
    if (self.startPoint.x <= self.xjGestureButton.frame.size.width / 2.0) {
        //音/量
        self.startVB = self.volumeViewSlider.value;
    } else {
        //亮度
        self.startVB = [UIScreen mainScreen].brightness;
    }
    //方向置为无
    self.direction = DirectionNone;
    //记录当前视频播放的进度
//    CMTime ctime = self.xjPlayer.currentTime;
//    self.startVideoRate = ctime.value / ctime.timescale / CMTimeGetSeconds(self.xjPlayer.currentItem.duration);;
    
}

#pragma mark - 结束触摸
- (void)touchesEndWithPoint:(CGPoint)point {
    if (self.direction == DirectionLeftOrRight) {

        [self getMediaInfo];
    
    }
}

#pragma mark - 拖动
- (void)touchesMoveWithPoint:(CGPoint)point {
    //得出手指在Button上移动的距离
    CGPoint panPoint = CGPointMake(point.x - self.startPoint.x, point.y - self.startPoint.y);
    //分析出用户滑动的方向
    if (self.direction == DirectionNone) {
        if (panPoint.x >= 30 || panPoint.x <= -30) {
            //进度
            self.direction = DirectionLeftOrRight;
        } else if (panPoint.y >= 30 || panPoint.y <= -30) {
            //音量和亮度
            self.direction = DirectionUpOrDown;
        }
    }
    
    if (self.direction == DirectionNone) {
        return;
    } else if (self.direction == DirectionUpOrDown) {
        //音量和亮度
        if (self.startPoint.x <= self.xjGestureButton.frame.size.width / 2.0) {
            //音量
            if (panPoint.y < 0) {
                //增大音量
                [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                if (self.startVB + (-panPoint.y / 30 / 10) - self.volumeViewSlider.value >= 0.1) {
                    [self.volumeViewSlider setValue:0.1 animated:NO];
                    [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                }
                
            } else {
                //减少音量
                [self.volumeViewSlider setValue:self.startVB - (panPoint.y / 30.0 / 10) animated:YES];
            }
            
        } else {
            
            //调节亮度
            if (panPoint.y < 0) {
                //增加亮度
                [[UIScreen mainScreen] setBrightness:self.startVB + (-panPoint.y / 30.0 / 10)];
            } else {
                //减少亮度
                [[UIScreen mainScreen] setBrightness:self.startVB - (panPoint.y / 30.0 / 10)];
            }
        }
    } else if (self.direction == DirectionLeftOrRight ) {
        //进度
        CGFloat rate = self.startVideoRate + (panPoint.x / 30.0 / 20.0);
        if (rate > 1) {
            rate = 1;
        } else if (rate < 0) {
            rate = 0;
        }
        self.currentRate = rate;
    }
}

- (void)userTapGestureAction:(UITapGestureRecognizer *)tap{
    if (tap.numberOfTapsRequired == 1) {
        [self showOrHidenMenuView];
        
    }else if (tap.numberOfTapsRequired == 2){
        [self playOrPauseAction];
    }
}

#pragma mark - 外部接口
/**
 *  如果想自己写底部菜单，可以移除我写好的菜单；然后通过接口和代理来控制视屏;
 */
- (void)removeXJplayerBottomMenu{
    [self.bottomMenuView removeFromSuperview];
}
/**
 *  暂停
 */
- (void)pause{
    [self playOrPauseAction];
}
/**
 *  开始
 */
- (void)play{
    [self playOrPauseAction];
}

-(void)prepareTo{

    [_IKJplayer prepareToPlay];

}

#pragma mark - 懒加载
- (void)setMJJPlayerUrl:(NSString *)MJJPlayerUrl{
    _MJJPlayerUrl = MJJPlayerUrl;
    
    if (isFirst) {
        if (!isHiden) {
            self.bottomMenuView.hidden = YES;
            isHiden = YES;
        }
        if (isPlay) {
            [self.IKJplayer pause];
            [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
            isPlay = NO;
        }
        [self setUserInteractionEnabled:NO];
        [self.loadingView startAnimating];
    }
    [self MJJPlayerInit];
    if (!isFirst) {
        [self addToolView];
        isFirst = YES;
    }
}

- (UIView *)bottomMenuView{
    if (_bottomMenuView == nil) {
        _bottomMenuView = [[UIView alloc] init];
        _bottomMenuView.backgroundColor = [UIColor colorWithRed:50.0/255.0 green:50.0/255.0 blue:50.0/255.0 alpha:1.0];
        _bottomMenuView.hidden = YES;
        isHiden = YES;
    }
    return _bottomMenuView;
}

- (UIButton *)playOrPauseBtn{
    if (_playOrPauseBtn == nil) {
        _playOrPauseBtn = [[UIButton alloc] init];
        [_playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        [_playOrPauseBtn addTarget:self action:@selector(playOrPauseAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playOrPauseBtn;
}

- (UIButton *)nextPlayerBtn{
    if (_nextPlayerBtn == nil) {
        _nextPlayerBtn = [[UIButton alloc] init];
        [_nextPlayerBtn setImage:[UIImage imageNamed:@"button_forward"] forState:UIControlStateNormal];
        [_nextPlayerBtn addTarget:self action:@selector(nextPlayerAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _nextPlayerBtn;
}

- (UIButton *)fullOrSmallBtn{
    if (_fullOrSmallBtn == nil) {
        _fullOrSmallBtn = [[UIButton alloc] init];
        [_fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
        [_fullOrSmallBtn addTarget:self action:@selector(fullOrSmallAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fullOrSmallBtn;
}

- (UILabel *)timeLabel{
    if (_timeLabel == nil) {
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.textColor = [UIColor whiteColor];
        _timeLabel.font = [UIFont systemFontOfSize:11.0];
        _timeLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel.text = @"00:00:00/00:00:00";
    }
    return _timeLabel;
}

- (UIProgressView *)loadProgressView{
    if (_loadProgressView == nil) {
        _loadProgressView = [[UIProgressView alloc] init];
    }
    return _loadProgressView;
}

- (UISlider *)playSlider{
    if (_playSlider == nil) {
        _playSlider = [[UISlider alloc] init];
        _playSlider.minimumValue = 0.0;
        
        UIGraphicsBeginImageContextWithOptions((CGSize){1,1}, NO, 0.0f);
        UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self.playSlider setThumbImage:[UIImage imageNamed:@"icon_progress"] forState:UIControlStateNormal];
        [self.playSlider setMinimumTrackImage:transparentImage forState:UIControlStateNormal];
        [self.playSlider setMaximumTrackImage:transparentImage forState:UIControlStateNormal];
        
        [_playSlider addTarget:self action:@selector(didSliderTouchDown) forControlEvents:UIControlEventTouchDown];
        
        [_playSlider addTarget:self action:@selector(didSliderTouchCancel) forControlEvents:UIControlEventTouchCancel];
        
        [_playSlider addTarget:self action:@selector(didSliderTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];

        [_playSlider addTarget:self action:@selector(didSliderTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        
        [_playSlider addTarget:self action:@selector(didSliderValueChanged) forControlEvents:UIControlEventValueChanged];
    }
    return _playSlider;
}

- (UIActivityIndicatorView *)loadingView{
    if (_loadingView == nil) {
        _loadingView = [[UIActivityIndicatorView alloc] init];
        [_loadingView startAnimating];
    }
    return _loadingView;
}

- (MPVolumeView *)volumeView {
    if (_volumeView == nil) {
        _volumeView  = [[MPVolumeView alloc] init];
        [_volumeView sizeToFit];
        for (UIView *view in [_volumeView subviews]){
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
                self.volumeViewSlider = (UISlider*)view;
                break;
            }
        }
    }
    return _volumeView;
}

- (XJGestureButton *)xjGestureButton{
    if (_xjGestureButton == nil) {
        //添加自定义的Button到视频画面上
        _xjGestureButton = [[XJGestureButton alloc] initWithFrame:xjPlayerFrame];
        _xjGestureButton.touchDelegate = self;
    }
    return _xjGestureButton;
}

//布局
- (void)layoutSubviews{

    
    self.bottomMenuView.frame = CGRectMake(0, self.height-60, self.width, 40);
    self.playOrPauseBtn.frame = CGRectMake(self.bottomMenuView.left+5, 8, 36, 23);
    if (isFull) {
        self.nextPlayerBtn.frame = CGRectMake(self.playOrPauseBtn.right, 5, 30, 30);
        self.bottomMenuView.frame = CGRectMake(0, self.height-40, self.width, 40);
        self.xjGestureButton.frame = self.window.bounds;
        self.volumeView.frame = CGRectMake(0, 0, self.frame.size.height, self.frame.size.height * 9.0 / 16.0);
    }else{
        self.nextPlayerBtn.frame = CGRectMake(self.playOrPauseBtn.right+5, 5, 0, 0);
        self.xjGestureButton.frame = xjPlayerFrame;
        self.volumeView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.width * 9.0 / 16.0);
    }
    self.fullOrSmallBtn.frame = CGRectMake(self.bottomMenuView.width-35, 0, 35, self.bottomMenuView.height);
    self.timeLabel.frame = CGRectMake(self.fullOrSmallBtn.left-108, 10, 108, 20);
    self.loadProgressView.frame = CGRectMake(self.playOrPauseBtn.right+self.nextPlayerBtn.width+7, 20,self.timeLabel.left-self.playOrPauseBtn.right-self.nextPlayerBtn.width-14, 31);
    self.playSlider.frame = CGRectMake(self.playOrPauseBtn.right+self.nextPlayerBtn.width+5, 5, self.loadProgressView.width+4, 31);
    
//    self.loadingView.frame = CGRectMake(self.centerX, self.centerY-20, 20, 20);
//    UITextField *filed=[[UITextField alloc]initWithFrame:CGRectMake(10, 10, 100, 100)];
//    //    [filed setBackground:[UIColor redColor]];
//    [self addSubview:filed];
    
}
-(void)getMediaInfo{
     // duration 总时间
    NSTimeInterval duration = _IKJplayer.duration;
    NSInteger intDuration = duration + 0.5;
    if (intDuration > 0) {
        self.playSlider.maximumValue = duration;
    } else {
        self.playSlider.maximumValue = 1.0f;
    }
    // position 当前时间
    NSTimeInterval position;
    
    if (_isMediaSliderBeingDragged) {
        position = self.playSlider.value;
    } else {
        position = _IKJplayer.currentPlaybackTime;
    }
    NSInteger intPosition = position + 0.5;
    if (intDuration > 0) {
        self.playSlider.value = position;
    } else {
        self.playSlider.value = 1.0f;
    }
    NSString *timeString=[self MJJPlayerTimeStyle:intPosition];
    self.timeLabel.text = [NSString stringWithFormat:@"00:%@/00:%@",timeString,[self MJJPlayerTimeStyle:_IKJplayer.duration]];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(getMediaInfo) object:nil];
    if (!self.bottomMenuView.hidden) {
        [self performSelector:@selector(getMediaInfo) withObject:nil afterDelay:0.5];
    }
}
#pragma mark - 自定义事件
//定义视屏时长样式
- (NSString *)MJJPlayerTimeStyle:(NSInteger)time{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (time/3600>1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    }else{
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showTimeStyle = [formatter stringFromDate:date];
    return showTimeStyle;
}


#pragma mark Install Movie Notifications

/* Register observers for the various movie object notifications. */
-(void)installMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadStateDidChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:_IKJplayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                               object:_IKJplayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaIsPreparedToPlayDidChange:)
                                                 name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:_IKJplayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:_IKJplayer];
}
- (void)loadStateDidChange:(NSNotification*)notification
{
    //    MPMovieLoadStateUnknown        = 0,
    //    MPMovieLoadStatePlayable       = 1 << 0,
    //    MPMovieLoadStatePlaythroughOK  = 1 << 1, // Playback will be automatically started in this state when shouldAutoplay is YES
    //    MPMovieLoadStateStalled        = 1 << 2, // Playback will be automatically paused in this state, if started
    
    IJKMPMovieLoadState loadState = _IKJplayer.loadState;
    
    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {
        [self prepareTo];
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStatePlaythroughOK: %d\n", (int)loadState);
    } else if ((loadState & IJKMPMovieLoadStateStalled) != 0) {
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStateStalled: %d\n", (int)loadState);
    } else {
        NSLog(@"loadStateDidChange: ???: %d\n", (int)loadState);
    }
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification
{
    //    MPMovieFinishReasonPlaybackEnded,
    //    MPMovieFinishReasonPlaybackError,
    //    MPMovieFinishReasonUserExited
    int reason = [[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    
    switch (reason)
    {
        case IJKMPMovieFinishReasonPlaybackEnded:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackEnded: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonUserExited:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonUserExited: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonPlaybackError:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackError: %d\n", reason);
            break;
            
        default:
            NSLog(@"playbackPlayBackDidFinish: ???: %d\n", reason);
            break;
    }
}

- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification
{
    NSLog(@"mediaIsPreparedToPlayDidChange\n");
}

- (void)moviePlayBackStateDidChange:(NSNotification*)notification
{
    //    MPMoviePlaybackStateStopped,
    //    MPMoviePlaybackStatePlaying,
    //    MPMoviePlaybackStatePaused,
    //    MPMoviePlaybackStateInterrupted,
    //    MPMoviePlaybackStateSeekingForward,
    //    MPMoviePlaybackStateSeekingBackward
    
    switch (_IKJplayer.playbackState)
    {
        case IJKMPMoviePlaybackStateStopped: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped", (int)_IKJplayer.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePlaying: {
            NSLog(@"播放成功");
            [self.loadingView stopAnimating];
            [self setUserInteractionEnabled:YES];//成功才能弹出底部菜单
            [self getMediaInfo];
//            self.avTotalTime = [self MJJPlayerTimeStyle:_IKJplayer.duration];//获取视屏总长及样式

            
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_IKJplayer.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePaused: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_IKJplayer.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStateInterrupted: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: interrupted", (int)_IKJplayer.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStateSeekingForward:
        case IJKMPMoviePlaybackStateSeekingBackward: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: seeking", (int)_IKJplayer.playbackState);
            break;
        }
        default: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: unknown", (int)_IKJplayer.playbackState);
            break;
        }
    }
}

#pragma mark Remove Movie Notification Handlers

/* Remove the movie notification observers from the movie object. */
-(void)removeMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_IKJplayer];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_IKJplayer];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_IKJplayer];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_IKJplayer];
}

#pragma mark - 屏幕方向改变的监听
//屏幕方向改变时的监听
- (void)orientChange:(NSNotification *)notification{
    UIDeviceOrientation orient = [[UIDevice currentDevice] orientation];
    switch (orient) {
            isAutoOrient = YES;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        {
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            self.frame = xjPlayerFrame;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
            isFull = NO;
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:NO];
            }
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeLeft:      // Device oriented horizontally, home button on the right
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:YES];
            }
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:YES];
            }
            
            [self layoutSubviews];
        }
            break;
        default:
            break;
    }
}

@end
