
@import Foundation;
#import "MPNativeAd.h"

/// This class is responsible for "mapping" a native content ad to the interface
/// expected by the Google Mobile Ads SDK. The names and data types of assets provided
/// by a mediated network don't always line up with the ones expected by the Google
/// Mobile Ads SDK (one might have "title" while the other expects "headline," for
/// example). It's the job of this "mapper" class to smooth out those wrinkles.
@interface MoPubAdapterMediatedNativeAd : NSObject<GADMediatedNativeContentAd>

- (instancetype)initWithMoPubNativeAd:(nonnull MPNativeAd *)mopubNativeAd mappedImages: (nullable NSMutableDictionary *) downloadedImages;

@end
