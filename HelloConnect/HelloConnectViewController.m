//
//  HelloConnectViewController.m
//  HelloConnect
//
//  Created by neurosky on 1/24/14.
//  Copyright (c) 2014 neurosky. All rights reserved.
//

#import "HelloConnectViewController.h"

@interface HelloConnectViewController ()

@end

@implementation HelloConnectViewController
{
    dispatch_queue_t workBackgroundQueue;
     dispatch_queue_t ecgQueue;
}
// 追加Library：アウトレット接続とアクション接続
@synthesize connectionStatus;
@synthesize userNo;
@synthesize recordTimer;

@synthesize ekgLineView;

@synthesize toolbar;
@synthesize devicePicker;
@synthesize devicesArray;

#define TEST_SLEEP_DATA_FILE @"SleepRawSample"
#define SLEEP_START_TS 1411077600.00000
#define SLEEP_END_TS 1411102800.00000
#define SLEEP_DOWN_SAMPLE 5

#define FIND_ME_TEST_SYNC_IN_BACKGROUND

#define FIND_ME_DISABLE_ALARM_GOALS
//#define DISABLE_ALARM_GOALS

- (void)viewDidLoad // HelloMWMに遷移したときの処理
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    toolbar.hidden = YES;
    devicePicker.hidden = YES;
    
    devicePicker.delegate = self;
    devicePicker.dataSource = self;
    
    tempDevicesArray = [[NSMutableArray alloc] init];
    devicesArray = tempDevicesArray;
    
    deviceTypeArray =[[NSMutableArray alloc] init];
    devNameArray = [[NSMutableArray alloc] init];
    
    mfgIDArray = [[NSMutableArray alloc] init];
    
    //-init sgDevice before nTGBeManager
    
    mwDevice = [MWMDevice sharedInstance];   // MWM Deviceの設定
    [mwDevice setDelegate:self];
    NSLog(@"MWM SDK version = %@",mwDevice.getVersion);
    //enable console log here：ここでコンソールログを有効にする
    //[mwDevice enableConsoleLog:YES];
    
    NSDate *epochnow = [NSDate date];
    uint32_t nowEpochSeconds = [epochnow timeIntervalSince1970];
    uint32_t *sleeptime = (uint32_t*)malloc(sizeof(uint32_t)*3);
    sleeptime[0] = nowEpochSeconds;
    sleeptime[1] = nowEpochSeconds++;
    sleeptime[2] = nowEpochSeconds+2;
    
    NSMutableArray *sleepTimeArray = [[NSMutableArray alloc] initWithCapacity:3];
    
    for(int i = 0; i < 3; i++){
        [sleepTimeArray addObject: [NSDate dateWithTimeIntervalSince1970:sleeptime[i]]];
    }
     ecgQueue=dispatch_queue_create("ecg_queue", DISPATCH_QUEUE_SERIAL);
    

}


-(void)viewWillAppear:(BOOL)animated{ // 遷移が一度だけのみ実行
    
    put_alert = put_alertLast = nil;
    labEKGalert = labEKGalertLast = nil;
    labEKGcount = 0;
    labEKGstartTime = nil;
    labEKGsampleRate = 0;
    labEKGrealTime = false;
    labEKGcomment = nil;
}

-(void)viewWillDisappear:(BOOL)animated{
  //  [sgDevice teardownManager];
}

- (void)alertView:(UIAlertView *)bondDialogView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        //NSLog(@"Button NO");
        // NO, do something
    }
    else if (buttonIndex == 1) {
        //NSLog(@"Button YES");
      //  [sgDevice takeBond];
        // Yes - take the bond
    }
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
    // //NSLog(@"numberOfComponentsInPickerView-------");
    //
    // only 1 scrollable list：スクロール可能なリストが一つしかない
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component{
    // //NSLog(@"numberOfRowsInComponent-------");
    int count;
    count = (int) devicesArray.count;
    return count;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component{
    // //NSLog(@"titleForRow-------");
    NSString *listItem;
    listItem =  [NSString stringWithFormat:@"%@:%@",[mfgIDArray objectAtIndex:row],[devNameArray objectAtIndex:row]];
    
    return listItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.：再現可能なリソースを破棄します。
}

-(void)put_alertWithOK: (NSString*) title message:(NSString*) message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        put_alertLast = put_alert;
        put_alert = [[UIAlertView alloc]initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@" OK ", nil];
        
        if (put_alertLast != nil) {
            [put_alertLast dismissWithClickedButtonIndex:0 animated:NO];
        }
        [put_alert show];
    }); // do all alerts on the main thread：すべてのアラートを本スレッドで実行
}


- (IBAction)onDisconnectClicked:(id)sender{
    [mwDevice disconnectDevice];
    self.connectionStatus.text = @"未接続";
    self.connectionStatus.textColor = [UIColor whiteColor];
}

- (IBAction)onSCandidateClicked:(id)sender
{
    [mwDevice scanDevice]; // deviceFoundメソッドへ移行
    
    toolbar.hidden = NO;
    devicePicker.hidden = NO;
}

- (IBAction)onFinishedButtonClicked:(id)sender {   // ボタン”Select”が押された時の処理
    toolbar.hidden = YES;
    devicePicker.hidden = YES;
   // [nTGBleManager candidateStopScan];
    
    if (devicesArray.count < 1) {
        return;
    }
    
    int row_number = (int) [devicePicker selectedRowInComponent:0];
    if (row_number < 0) {
        //NSLog(@"%s STRANGE devicesArray row number: %d", __func__, row_number);
    }
    
    if (row_number >= 0)
    {
        NSString *deviceID = [devicesArray objectAtIndex:row_number];
        [mwDevice connectDevice:deviceID];  // 選択されたDeviceに接続→「-(void)didConnect」メソッドへ移る
        
        // now release the lists so that they are empty and prepared for the next time.
        tempDevicesArray = [[NSMutableArray alloc] init];
        devicesArray = tempDevicesArray;
        
        deviceTypeArray =[[NSMutableArray alloc] init];
        devNameArray = [[NSMutableArray alloc] init];
        mfgIDArray = [[NSMutableArray alloc] init];

        // put picker into a good state
        devicePicker.userInteractionEnabled = NO;
        [devicePicker reloadAllComponents];
    }
}

-(NSString *)formatToken:(id)tokenObj // 4/7_何これ？
{
    printf("formatToken\n");
    NSString *hexStr = @"";
    if ([tokenObj isKindOfClass:[NSData class]])
    {
        Byte *bytes = (Byte*)[tokenObj bytes];
        for(int i=0;i< 20;i++)
        {
            NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];
            if([newHexStr length]==1)
                hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
            else
                hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
            
            NSLog(@"bytes 的16进制数为:%@",hexStr);
        }
    }else if ([tokenObj isKindOfClass:[NSString class]])
    {
        hexStr = (NSString *)tokenObj;
         NSLog(@"String format");
    }else
    {
        NSLog(@"%@", tokenObj);
    }
    return hexStr;
}
// configMWMの処理をコメントアウトすると警告がなぜか出るので、ひとまず残しておく。
//static int i = 0;
- (IBAction)configMWM:(id)sender
{
//    [mwDevice readConfig];
//    NSLog(@"--> mwm cmd: %d",i);
////    [sgDevice ConfigureMWMWithCMD:(i ++)%2];
////    usleep(1000 * 1000);
////
}

// MWM Dveice関連の変数宣言
int rawdataCnt = 0;
int user_num = 0;
BOOL btnRec = NO;
BOOL outBlinkData = NO;
BOOL connectBool = NO;
NSDate *startDate;


//NSDateFormatter *nowFormatter = [[NSDateFormatter alloc] init];
//nowFormatter.dateFormat = @"HH:mm:ss.SSS";
//NSString *stringNow = [nowFormatter stringFromDate:now];
//self.recordTimer.text = stringNow;

//  記録開始ボタン
- (IBAction)onRecordClicked:(id)sender {
    if (btnRec == YES){
        btnRec = NO;
        [sender setTitle:@"記録開始" forState:UIControlStateNormal];
        [sender setBackgroundColor:[UIColor greenColor] ];
        
        self.recordTimer.text = @"00:00:00";
        outBlinkData = YES;
    }
    else if (btnRec == NO){
        btnRec = YES;
        [sender setTitle:@"記録停止" forState:UIControlStateNormal];
        [sender setBackgroundColor:[UIColor redColor] ];
        if (connectBool == YES){
            NSDate *now = [NSDate date];
            startDate = now;
        }
        else if (connectBool == NO){
            self.recordTimer.text = @"00:00:00";
        }
    }
}

//MWM Device delegate-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->
-(void)deviceFound:(NSString *)devName MfgID:(NSString *)mfgID DeviceID:(NSString *)deviceID
{
    // printf("%s\n", [mfgID UTF8String]); // MWMのIDの確認
    //mfgID is null or @"", NULL
    if ([mfgID isEqualToString:@""] || nil == mfgID || NULL == mfgID) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{  // do all alerts on the main thread
        
        if (![devicesArray containsObject:deviceID])
        {
            [tempDevicesArray addObject:deviceID];
            devicesArray = tempDevicesArray;
            [devNameArray addObject:devName];
            [mfgIDArray addObject:mfgID];
            //store
            [deviceTypeArray addObject:@0];
            [devicePicker reloadAllComponents];
        }
        
        if (devicesArray.count > 0) {
            devicePicker.userInteractionEnabled = YES;
        }
        else{
            devicePicker.userInteractionEnabled = NO;
        }
    });
    // userNoの表示
    //userNoを表示するとエラー
//    if ([mfgID isEqualToString:@"NS135F95"]){
//        user_num = 2;
//        self.userNo.text = @"userNo.2";
//    }

}
-(void)didConnect
{
    connectBool = YES;
    printf("\n接続（userNo.%d）\n",user_num);
    [[MWMDevice sharedInstance] enableLoggingWithOptions:LoggingOptions_Processed | LoggingOptions_Raw];
}

-(void)didDisconnect
{
    connectBool = NO;
    printf("\n接続解除\n");
    Raw = [NSMutableString stringWithString:@""];
    Blink = [NSMutableString stringWithString:@""];
    rawdataCnt = 0;
    user_num = 0;
}

// ---- Rawdataを保存する処理 ---
-(void)eegSample:(int)sample // eegSample＝Rawdata。
{
    ///0.1秒スリープする
    //[NSThread sleepForTimeInterval:0.1];
    
    [ekgLineView addValue:sample]; // ekgLineView（グラフ）にRawdataが追加される
    NSString *str_sample = [NSString stringWithFormat:@"%d",sample];
    
    // 記録開始ボタンがONのときの処理
    if (btnRec == YES){
        // 記録時間の表示
        NSDate *now = [NSDate date];
        NSTimeInterval intervalTime = [now timeIntervalSinceDate:startDate];
        NSString *str1 = [NSString stringWithFormat:@"%f", intervalTime];
        self.recordTimer.text = str1;
        
        // rawdataをカンマ区切りで連結
        NSString *str2 = [str_sample stringByAppendingString:@"\n"];
        [Raw appendString:str2];
        rawdataCnt++;
        //5120(10秒に1回)
        //10240(20秒
        //15360(30秒に1回)
        //20480(40秒
        //25600(50秒
        //30720(1分に1回)
        //153600=512*60*5(5分に1回)
        //307200(10分に1回)
        if(rawdataCnt >= 5120){
            // SQLiteで保存（したい）
            NSDate *now = [NSDate date];
            NSDateFormatter *nowFormatter = [[NSDateFormatter alloc] init];
            nowFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss.SSS"; // 日時（秒数まで）の情報を取得
            NSString *stringNow = [nowFormatter stringFromDate:now];
            
            // パラメータの作成
            //NSString *url = @"https://clicker.tokyo/api/rawdata";
            //NSString *param = [NSString stringWithFormat:@"Raw=%@", Raw];
            NSString *url = @"https://clicker.tokyo/api/rawdata2";
            //NSString *param = [NSString stringWithFormat:@"Raw=%@&User_id=%@", Raw,user_num];
            //数字をスマホの数字に合わせて変更してビルドする(@"7"のところ)
            NSString *param = [NSString stringWithFormat:@"Raw=%@&User_id=%@", Raw,@"8"];
            // リクエストの生成
            NSMutableURLRequest * request;
            request = [NSMutableURLRequest new];
            [request setHTTPMethod:@"POST"];
            [request setURL:[NSURL URLWithString:url]];
            [request setHTTPBody:[param dataUsingEncoding:NSUTF8StringEncoding]];

            // 通信開始
            NSURLResponse *response = nil;
            NSError *error=nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            if (error != nil) {
                NSLog(@"Error! %@", error);
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            if (httpResponse.statusCode != 200) {
                NSLog(@"statuscode: %ld", (long)httpResponse.statusCode);
                return;;
            }

            // printf("%s,%s",[stringNow UTF8String],[Raw UTF8String]);   // 実験時のデータ取得用コード
            // 各変数を初期化
            Raw = [NSMutableString stringWithString:@""];
            rawdataCnt = 0;
           
        }
    }
}

// --- Rawdata以外の信号取得 ---
-(void)eSense:(int)poorSignal Attention:(int)attention Meditation:(int)meditation // eegSampleメソッドの後
{
    // ノイズ強度
    if (poorSignal == 0){ // 新しくボタンを追加して、ノイズ強度を二極化させる。
        self.connectionStatus.text = @"接続中";
        self.connectionStatus.textColor = [UIColor greenColor];
    }
    else{
        self.connectionStatus.text = @"不安定";
        self.connectionStatus.textColor = [UIColor yellowColor];
    }
    // 注意度と瞑想度
    if (btnRec == YES){
        NSDate *now = [NSDate date];
        NSDateFormatter *nowFormatter = [[NSDateFormatter alloc] init];
        nowFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss.SSS";
        NSString *stringNow = [nowFormatter stringFromDate:now];
        printf("Time:%s,Algolithm:%d,%d,%d,",[stringNow UTF8String],poorSignal,attention,meditation);
    }
}
-(void)eegPowerDelta:(int)delta Theta:(int)theta LowAlpha:(int)lowAplpha HighAlpha:(int)highAlpha // eSenseメソッドの後
{
    if (btnRec == YES){
        printf("EEGPower:%d,%d,%d,%d,",delta,theta,lowAplpha,highAlpha);
    }
}
-(void)eegPowerLowBeta:(int)lowBeta HighBeta:(int)highBeta LowGamma:(int)lowGamma MidGamma:(int)midGamma //eegPowerDeltaメソッドの後
{
    if (btnRec == YES){
        printf("%d,%d,%d,%d\n",lowBeta,highBeta,lowGamma,midGamma); // 最後に改行
    }
}
-(void)eegBlink:(int)blinkValue // 瞬きを検知したタイミングで呼ばれる
{
    if (btnRec == YES){
        NSDate *now = [NSDate date];
        NSDateFormatter *nowFormatter = [[NSDateFormatter alloc] init];
        nowFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss.SSS_";
        NSString *stringNow = [nowFormatter stringFromDate:now];
        [Blink appendString:stringNow];
        NSString *str_blinkValue = [NSString stringWithFormat:@"%d",blinkValue];
        NSString *str = [str_blinkValue stringByAppendingString:@","];
        [Blink appendString:str];
    }
    if (outBlinkData == YES){
        outBlinkData = NO;
        printf("%s",[Blink UTF8String]);   // 実験時のデータ取得用コード
        Blink = [NSMutableString stringWithString:@""];
    }
}

//-(void)mwmBaudRate:(int)baudRate NotchFilter:(int)notchFilter // 何これ？
//{
//    NSLog(@"%s >>>>>>>-----mwmBaudRate:%d NotchFilter:%d ", __func__,  baudRate, notchFilter);
//}

//<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--

@end

