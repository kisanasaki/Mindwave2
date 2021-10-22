/**
 *  This Class is used for Seagull device：このクラスはSeagullデバイスに用いられます。
 *（マニュアルp.11）MWMDeviceクラスは、NeuroSky HardwareのアクセサリーとiOSデバイスとの接続を処理します。
 *  Copyright (c) 2015 neurosky. All rights reserved.
 */

#import <CoreBluetooth/CoreBluetooth.h>

#import "MWMDelegate.h"
#import "MWMEnum.h"

//-
@interface MWMDevice : NSObject  <MWMDelegate>
{
}

@property (nonatomic, assign) id<MWMDelegate> delegate;
// the Shared Stream Manager
+ (MWMDevice *)sharedInstance;
// SDK Version
-(NSString *) getVersion; // main処理で「MWMDevice.getVersion」と用いる。HelloConnectViewController.m/59行を参照。

//scan
-(void)scanDevice;

//stopScan
-(void)stopScanDevice;

//connect
-(void)connectDevice:(NSString *)deviceID;
//disconnect
-(void)disconnectDevice;

//config
-(void)writeConfig:(TGMWMConfigCMD)cmd;
-(void)readConfig;

-(void)enableConsoleLog:(BOOL)enabled;
// logging
-(NSString *)enableLoggingWithOptions:(unsigned)option;
-(void)stopLogging;

@end
