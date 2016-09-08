    //
// Copyright (C) 2015 Google, Inc.
//
// SampleAdapter.m
// Sample Ad Network Adapter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

@import GoogleMobileAds;

#import "GADMAdapterMoPub.h"

#import "GADMAdNetworkConnectorProtocol.h"
#import "GADMEnums.h"
#import "MPAdView.h"
#import "MPInterstitialAdController.h"
#import "MPNativeAdDelegate.h"
#import "MPNativeAd.h"
#import "MPStaticNativeAdRendererSettings.h"
#import "MPStaticNativeAdRenderer.h"
#import "MPNativeAdRequest.h"
#import "MPNativeAdRequestTargeting.h"
#import "MoPubAdapterMediatedNativeAd.h"
#import "MPNativeAdConstants.h"


/// Constant for adapter error domain.
static NSString *const adapterErrorDomain = @"com.mopub.mobileads.MoPubAdapter";

@interface GADMAdapterMoPub () <MPAdViewDelegate, MPInterstitialAdControllerDelegate,
                             MPNativeAdDelegate>

/// Connector from Google Mobile Ads SDK to receive ad configurations.
@property(nonatomic, weak) id<GADMAdNetworkConnector> connector;

/// Handle banner ads from Sample SDK.
@property(nonatomic, strong) MPAdView *bannerAd;

/// Handle interstitial ads from Sample SDK.
@property(nonatomic, strong) MPInterstitialAdController *interstitialAd;

/// An ad loader to use in loading native ads from Sample SDK.
@property(nonatomic, strong) MPNativeAd *nativeAd;

@property(nonatomic, strong) MoPubAdapterMediatedNativeAd *mediatedAd;


@end

@implementation GADMAdapterMoPub


/// Array of GADNativeAdImage objects related to the advertised application.
NSArray *_images;

/// A set of strings representing loaded images.
NSMutableDictionary *_imagesDictionary;

/// Application icon.
GADNativeAdImage *_icon;

/// A set of string representing all native ad images.
NSSet *_nativeAdImages;

/// Serializes ivar usage.
dispatch_queue_t _lockQueue;

+ (NSString *)adapterVersion {
  return @"1.0";
}

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
  // OPTIONAL: Create your own class implementating GADAdNetworkExtras and return that class type
  // here for your publishers to use. This class does not use extras.

  return Nil;
}

- (instancetype)initWithGADMAdNetworkConnector:(id<GADMAdNetworkConnector>)connector {
  self = [super init];
  if (self) {
    _connector = connector;
  }
  return self;
}

- (void)getInterstitial {
  self.interstitialAd = [[MPInterstitialAdController alloc] init];
  self.interstitialAd.delegate = self;
  self.interstitialAd.adUnitId = self.connector.publisherId;
  [self.interstitialAd loadAd];
  NSLog(@"Requesting interstitial from MoPub");
    
}

- (void)stopBeingDelegate {
    self.bannerAd.delegate = nil;
    self.interstitialAd.delegate = nil;
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)rootViewController {
    if (self.interstitialAd.ready) {
        [self.interstitialAd showFromViewController:rootViewController];
    }
}

#pragma mark MoPub Ad Interstitial delegate methods

- (void)interstitialDidLoadAd:(MPInterstitialAdController *)interstitial {
    [self.connector adapterDidReceiveInterstitial:self];
}

- (void)interstitialDidFailToLoadAd:(MPInterstitialAdController *)interstitial {
    NSError *adapterError = [NSError errorWithDomain:adapterErrorDomain code:0 userInfo:nil];
    [self.connector adapter:self didFailAd:adapterError];
}

- (void)interstitialWillAppear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterWillPresentInterstitial:self];
}

- (void)interstitialWillDisappear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterWillDismissInterstitial:self];
}

- (void)interstitialDidDisappear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterDidDismissInterstitial:self];
}


//Loading Banner Ads

- (void)getBannerWithSize:(GADAdSize)adSize {

  self.bannerAd = [[MPAdView alloc] initWithAdUnitId:[self.connector credentials][@"ad_unit"] size: CGSizeMake(adSize.size.width, adSize.size.height) ] ;

  self.bannerAd.delegate = self;
  self.bannerAd.adUnitId = self.connector.publisherId;

  [self.bannerAd loadAd];
  NSLog(@"Requesting banner from Sample Ad Network");
}


- (BOOL)isBannerAnimationOK:(GADMBannerAnimationType)animType {
    return YES;
}

// Loading Native Ads

- (void)getNativeAdWithAdTypes:(NSArray *)adTypes options:(NSArray *)options {
  
  MPStaticNativeAdRendererSettings *settings = [MPStaticNativeAdRendererSettings alloc];
  
  MPNativeAdRendererConfiguration *config = [MPStaticNativeAdRenderer rendererConfigurationWithRendererSettings:settings];
  NSString *moPubPublisherId = [self.connector credentials][@"ad_unit"]; // for facebook testing @"1ceee46ba9744155aed48ee6277ecbd6"; //
    
  MPNativeAdRequest *adRequest = [MPNativeAdRequest requestWithAdUnitIdentifier: moPubPublisherId rendererConfigurations:@[config]];
                                                
  MPNativeAdRequestTargeting *targeting = [MPNativeAdRequestTargeting targeting];
    CLLocation *currentlocation = [[CLLocation alloc] initWithLatitude:self.connector.userLatitude longitude:self.connector.userLongitude];
    targeting.location = currentlocation;
    
  [adRequest startWithCompletionHandler:^(MPNativeAdRequest *request, MPNativeAd *response, NSError *error) {
      if (error) {
          [self.connector adapter:self didFailAd:error];
      }
      else {
          self.nativeAd = response;
          self.nativeAd.delegate = self;
      
          if(options!=nil){
    
              for (GADNativeAdImageAdLoaderOptions *imageOptions in options) {
                  if (![imageOptions isKindOfClass:[GADNativeAdImageAdLoaderOptions class]]) {
                      continue;
                  }
                  
                  // Load only image urls
                  if(imageOptions.disableImageLoading)
                  {
                      _mediatedAd = [[MoPubAdapterMediatedNativeAd alloc] initWithMoPubNativeAd:self.nativeAd mappedImages:nil];
                      [self.connector adapter:self didReceiveMediatedNativeAd:_mediatedAd];
                  }
              }
          }
        
          [self loadNativeAdImages];

      }

  }];
    
  
  NSLog(@"Requesting native ad from Sample Ad Network");
}

//Helper classes for downloading images

- (void)loadNativeAdImages {
    _imagesDictionary = [[NSMutableDictionary alloc] init];
    // Load icon and cover image, and notify the  connector when completed.
    NSURL *iconURL = [NSURL URLWithString:self.nativeAd.properties[kAdIconImageKey]];
    NSURL *coverImageURL = [NSURL URLWithString:self.nativeAd.properties[kAdMainImageKey]];
    [self loadCoverImageForURL:coverImageURL];
    [self loadIconForURL:iconURL];
}
// Load main image for URL.
- (void)loadCoverImageForURL:(NSURL *)coverImageURL {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __strong typeof(self) strongSelf = weakSelf;
        NSData *imageData = [NSData dataWithContentsOfURL:coverImageURL];
        UIImage *image = [UIImage imageWithData:imageData];
        GADNativeAdImage *nativeAdImage = [[GADNativeAdImage alloc] initWithImage:image];
        if (nativeAdImage) {
            _images = @[ nativeAdImage ];
            [strongSelf completedLoadingNativeAdImage:nativeAdImage imageKey:kAdMainImageKey];
        }
        });
}
// Load icon image for URL.
- (void)loadIconForURL:(NSURL *)iconURL {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __strong typeof(self) strongSelf = weakSelf;
        NSData *imageData = [NSData dataWithContentsOfURL:iconURL];
        UIImage *image = [UIImage imageWithData:imageData];
        GADNativeAdImage *nativeAdIcon = [[GADNativeAdImage alloc] initWithImage:image];
        if (nativeAdIcon) {
            _icon = nativeAdIcon;
            [strongSelf completedLoadingNativeAdImage:nativeAdIcon imageKey:kAdIconImageKey];
        }
    });
}

- (void)completedLoadingNativeAdImage:(GADNativeAdImage *)image imageKey:(NSString *)imageKey {
    
    [_imagesDictionary setObject:image forKey:imageKey];
   
    if ([_imagesDictionary count] < 2) {
        return;
        
    }
    if ([_imagesDictionary objectForKey:kAdIconImageKey] && [_imagesDictionary objectForKey:kAdMainImageKey]) {
        [self nativeAdImagesReady];
        return;
    }
    
    NSError *adapterError = [NSError errorWithDomain:adapterErrorDomain code:0 userInfo:nil];
    [self.connector adapter:self didFailAd:adapterError];
}

- (void)nativeAdImagesReady {
    _mediatedAd = [[MoPubAdapterMediatedNativeAd alloc] initWithMoPubNativeAd:self.nativeAd mappedImages:_imagesDictionary];
    [self.connector adapter:self didReceiveMediatedNativeAd:_mediatedAd];

}


@end

