/*****************************************************************************
 *  Copyright (c) 2011 Meta Watch Ltd.                                       *
 *  www.MetaWatch.org                                                        *
 *                                                                           *
 =============================================================================
 *                                                                           *
 *  Licensed under the Apache License, Version 2.0 (the "License");          *
 *  you may not use this file except in compliance with the License.         *
 *  You may obtain a copy of the License at                                  *
 *                                                                           *
 *    http://www.apache.org/licenses/LICENSE-2.0                             *
 *                                                                           *
 *  Unless required by applicable law or agreed to in writing, software      *
 *  distributed under the License is distributed on an "AS IS" BASIS,        *
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
 *  See the License for the specific language governing permissions and      *
 *  limitations under the License.                                           *
 *                                                                           *
 *****************************************************************************/

//
//  WidgetWeather.m
//  MWM
//
//  Created by Siqi Hao on 4/20/12.
//  Copyright (c) 2012 Meta Watch. All rights reserved.
//

#import "WidgetWeather.h"
#import "MWWeatherMonitor.h"

@implementation WidgetWeather

@synthesize preview, updateIntvl, updatedTimestamp, settingView, widgetSize, widgetID, delegate, previewRef;

@synthesize received, geoLocationEnabled, updatedTime, useCelsius, currentCityName, widgetName, weatherUpdateIntervalInMins;

static NSInteger widget = 10001;
static CGFloat widgetWidth = 96;
static CGFloat widgetHeight = 32;

+ (CGSize) getWidgetSize {
    return CGSizeMake(widgetWidth, widgetHeight);
}

- (id)init
{
    self = [super init];
    if (self) {
        widgetSize = CGSizeMake(widgetWidth, widgetHeight);
        preview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
        widgetID = widget;
        widgetName = @"Weather";
        received = NO;
        useCelsius  = YES;
        currentCityName = @"Helsinki";
        updateIntvl = 3600;
        updatedTimestamp = 0;
        
        [[MWWeatherMonitor sharedMonitor] setCity:currentCityName];
        
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSDictionary *dataDict = [prefs valueForKey:[NSString stringWithFormat:@"%d", widgetID]];
        if (dataDict == nil) {
            [self saveData];
        } else {
            useCelsius = [[dataDict valueForKey:@"useC"] boolValue];
            self.currentCityName = [dataDict valueForKey:@"city"];
            updateIntvl = [[dataDict valueForKey:@"updateInterval"] integerValue];
            NSLog(@"currentCityName: %@", currentCityName);
            [[MWWeatherMonitor sharedMonitor] setCity:currentCityName];
        }
        
        // Setting
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"WidgetWeatherSettingView" owner:nil options:nil];
        self.settingView = [topLevelObjects objectAtIndex:0];
        self.settingView.alpha = 0;
        [(UISegmentedControl*)[settingView viewWithTag:3001] addTarget:self action:@selector(toggleValueChanged:) forControlEvents:UIControlEventValueChanged];
        if (useCelsius) {
            [(UISegmentedControl*)[settingView viewWithTag:3001] setSelectedSegmentIndex:0];
        } else {
            [(UISegmentedControl*)[settingView viewWithTag:3001] setSelectedSegmentIndex:1];
        }
        
        [(UITextField*)[settingView viewWithTag:3002] setDelegate:self];
        [(UITextField*)[settingView viewWithTag:3002] setText:currentCityName];
        
        [(UIButton*)[settingView viewWithTag:3003] addTarget:self action:@selector(updateBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
        if (updateIntvl == 30*60) {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Half an Hour" forState:UIControlStateNormal];
        } else if (updateIntvl == 3600) {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Hourly" forState:UIControlStateNormal];
        } else if (updateIntvl == 2*3600) {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"2 Hours" forState:UIControlStateNormal];
        } else if (updateIntvl == 6*3600) {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"6 Hours" forState:UIControlStateNormal];
        } else if (updateIntvl == 24*3600) {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Daily" forState:UIControlStateNormal];
        } else {
            [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Hourly" forState:UIControlStateNormal];
            updateIntvl = 3600;
            [self saveData];
        }
        
    }
    return self;
}

- (void) saveData {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:currentCityName forKey:@"city"];
    [dataDict setObject:[NSNumber numberWithBool:useCelsius] forKey:@"useC"];
    [dataDict setObject:[NSNumber numberWithInteger:updateIntvl] forKey:@"updateInterval"];
    
    [prefs setObject:dataDict forKey:[NSString stringWithFormat:@"%d", widgetID]];
    
    //NSLog(@"WeatherData: %@", [dataDict description]);
    
    [prefs synchronize];
}

- (void) prepareToUpdate {
    [delegate widgetViewCreated:self];
}

- (void) stopUpdate {
}

- (void) update:(NSInteger)timestamp {
    if (updateIntvl < 0 && timestamp > 0) {
        return;
    }
    if (timestamp < 0 || timestamp - updatedTimestamp >= updateIntvl) {
        updatedTimestamp = timestamp;
        if ([[MWWeatherMonitor sharedMonitor] currentWeather]) {
            received = YES;
            [self drawWeather];
        } else {
            [self drawNullWeather];
        }
        
        [delegate widget:self updatedWithError:nil];
    }
    if (timestamp < 0) {
        updatedTimestamp = (NSInteger)[NSDate timeIntervalSinceReferenceDate];
    }

}

- (void) drawNullWeather {
    UIFont *font = [UIFont fontWithName:@"MetaWatch Small caps 8pt" size:8];   
    //UIFont *largeFont = [UIFont fontWithName:@"MetaWatch Large 16pt" size:16];
    CGSize size  = CGSizeMake(widgetWidth, widgetHeight);
    
    UIGraphicsBeginImageContextWithOptions(size,NO,1.0);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    //CGContextSetFillColorWithColor(ctx, [[UIColor clearColor]CGColor]);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, widgetWidth, widgetHeight));
    
    CGContextSetFillColorWithColor(ctx, [[UIColor blackColor]CGColor]);
    
    /*
     Draw the Weather
     */
    [@"No Weather Data" drawInRect:CGRectMake(0, 12, widgetWidth, widgetHeight) withFont:font lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentCenter];
    
    previewRef = CGBitmapContextCreateImage(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();   
    
    for (UIView *view in self.preview.subviews) {
        [view removeFromSuperview];
    }
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.tag = 7001;
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    [self.preview addSubview:imageView];
}

- (void) drawWeather {
    UIFont *font = [UIFont fontWithName:@"MetaWatch Small caps 8pt" size:8];   
    UIFont *largeFont = [UIFont fontWithName:@"MetaWatch Large 16pt" size:16];
    CGSize size  = CGSizeMake(widgetWidth, widgetHeight);

    UIGraphicsBeginImageContextWithOptions(size,NO,1.0);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    
    //CGContextSetFillColorWithColor(ctx, [[UIColor clearColor]CGColor]);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, widgetWidth, widgetHeight));
    
    CGContextSetFillColorWithColor(ctx, [[UIColor blackColor]CGColor]);
    
    /*
     Draw the Weather
     */
    NSString *temp;
    NSString *low;
    NSString *high;

    NSDictionary *weather = [[MWWeatherMonitor sharedMonitor] weatherDict];
    NSString *condition = [weather objectForKey:@"condition"];

    NSString *location = [weather objectForKey:@"postal_code"];
    
    if (useCelsius) {
        temp = [weather objectForKey:@"temp_c"];
        low = [weather objectForKey:@"low_c"];
        high = [weather objectForKey:@"high_c"];
    } else {
        temp = [weather objectForKey:@"temp_f"];
        low = [weather objectForKey:@"low"];
        high = [weather objectForKey:@"high"];
    }
    
    
    NSLog(@"%@, %@, %@, %@", condition, low, high, temp);
    UIImage *weatherIcon;
    if ([condition isEqualToString:@"Clear"]) {
        weatherIcon=[UIImage imageNamed:@"weather_sunny.bmp"];
    }else if ([condition isEqualToString:@"Rain"]) {
        weatherIcon=[UIImage imageNamed:@"weather_rain.bmp"];
    }else if ([condition isEqualToString:@"Fog"]) {
        weatherIcon=[UIImage imageNamed:@"weather_cloudy.bmp"];
    }else if ([condition isEqualToString:@"Cloudy"]) {
        weatherIcon=[UIImage imageNamed:@"weather_cloudy.bmp"];
    }else if ([condition isEqualToString:@"Mostly Sunny"]) {
        weatherIcon=[UIImage imageNamed:@"weather_sunny.bmp"];
    }else if ([condition isEqualToString:@"Chance of Showers"]) {
        weatherIcon=[UIImage imageNamed:@"weather_rain.bmp"];
    }else if ([condition isEqualToString:@"Chance of Rain"]) {
        weatherIcon=[UIImage imageNamed:@"weather_rain.bmp"];
    } else {
        NSLog(@"unknown weather");
        weatherIcon=[UIImage imageNamed:@"weather_sunny.bmp"];
    }
    
    [condition drawInRect:CGRectMake(0, 3, 41, 14) withFont:font lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentCenter];
    [location drawInRect:CGRectMake(0, 16+7, 41, 7) withFont:font lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentCenter];
    
    [weatherIcon drawInRect:CGRectMake(42, 4, 24, 24)];
    if (useCelsius) {
        [[NSString stringWithFormat:@"%@ C", temp] drawInRect:CGRectMake(65, 1, 31, 16) withFont:largeFont lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentRight];
    } else {
        [[NSString stringWithFormat:@"%@ F", temp] drawInRect:CGRectMake(65, 1, 31, 16) withFont:largeFont lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentRight];
    }
    
    
    [@"HI:" drawInRect:CGRectMake(69, 16, 32, 7) withFont:font lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentLeft];
    [high drawInRect:CGRectMake(82, 16, 14, 7) withFont:font lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentRight];
    
    [@"LO:" drawInRect:CGRectMake(69, 16 + 7, 32, 7) withFont:font lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentLeft];
    [low drawInRect:CGRectMake(82, 16 + 7, 14, 7) withFont:font lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentRight];
    
    
    // transfer image
    
    previewRef = CGBitmapContextCreateImage(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();   
    
    for (UIView *view in self.preview.subviews) {
        [view removeFromSuperview];
    }
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.tag = 7001;
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    [self.preview addSubview:imageView];

}

- (void) toggleValueChanged:(id)sender {
    UISegmentedControl *segCtrl = (UISegmentedControl*)sender;
    if (segCtrl.selectedSegmentIndex == 0) {
        // C
        useCelsius = YES;
    } else {
        // F
        useCelsius = NO;
    }
    [self saveData];
    [self drawWeather];
    [delegate widget:self updatedWithError:nil];
}

- (void) textFieldDidBeginEditing:(UITextField *)textField {
    [UIView beginAnimations:nil context:NULL];
    [[[[UIApplication sharedApplication] windows] objectAtIndex:0] setCenter:CGPointMake(160, 20)];
    [UIView commitAnimations];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [UIView beginAnimations:nil context:NULL];
    [[[[UIApplication sharedApplication] windows] objectAtIndex:0] setCenter:CGPointMake(160, 240)];
    [UIView commitAnimations];
    [textField resignFirstResponder];
    
    if ([currentCityName isEqualToString:textField.text]) {
        return NO;
    }
    self.currentCityName = textField.text;
    if (currentCityName.length == 0) {
        currentCityName = @"Helsinki";
    }
    [[MWWeatherMonitor sharedMonitor] setCity:currentCityName];
    
    [self saveData];
    
    [self update:-1];
    
    return NO;
}

- (void) updateBtnPressed:(id)sender {
    [[[UIActionSheet alloc] initWithTitle:@"Select update interval" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Half an Hour", @"Hourly", @"2 Hours", @"6 Hours", @"Daily", nil] showInView:self.settingView];
    
}

- (void) actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Half an Hour" forState:UIControlStateNormal];
        updateIntvl = 30*60;
    } else if (buttonIndex == 1) {
        [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Hourly" forState:UIControlStateNormal];
        updateIntvl = 3600;
    } else if (buttonIndex == 2) {
        [(UIButton*)[settingView viewWithTag:3003] setTitle:@"2 Hours" forState:UIControlStateNormal];
        updateIntvl = 2*3600;
    } else if (buttonIndex == 3) {
        [(UIButton*)[settingView viewWithTag:3003] setTitle:@"6 Hours" forState:UIControlStateNormal];
        updateIntvl = 6*3600;
    } else if (buttonIndex == 4) {
        [(UIButton*)[settingView viewWithTag:3003] setTitle:@"Daily" forState:UIControlStateNormal];
        updateIntvl = 24*3600;
    }
    [self saveData];
}

- (void) dealloc {
    [self stopUpdate];
    [delegate widgetViewShoudRemove:self];
}

@end
