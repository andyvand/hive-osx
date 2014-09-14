//
//  HIProfileViewController.m
//  Hive
//
//  Created by Jakub Suder on 30.08.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "BCClient.h"
#import "HIBitcoinFormatService.h"
#import "HIContactInfoViewController.h"
#import "HICurrencyFormatService.h"
#import "HIExchangeRateService.h"
#import "HINameFormatService.h"
#import "HIProfile.h"
#import "HIProfileViewController.h"
#import "NSColor+Hive.h"
#import "NSDecimalNumber+HISatoshiConversion.h"

@interface HIProfileViewController () <HIExchangeRateObserver, HINameFormatServiceObserver> {
    HIProfile *_profile;
    HIContactInfoViewController *_infoPanel;
}

@property (nonatomic, weak) IBOutlet NSImageView *photoView;
@property (nonatomic, weak) IBOutlet NSTextField *nameLabel;
@property (nonatomic, weak) IBOutlet NSTextField *balanceLabel;
@property (nonatomic, weak) IBOutlet NSTextField *convertedBalanceLabel;
@property (nonatomic, weak) IBOutlet NSPopUpButton *convertedCurrencyPopupButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *bitcoinCurrencyPopupButton;
@property (nonatomic, weak) IBOutlet NSView *contentView;

@property (nonatomic, strong, readonly) HIExchangeRateService *exchangeRateService;
@property (nonatomic, strong, readonly) HIBitcoinFormatService *bitcoinFormatService;
@property (nonatomic, copy) NSDecimalNumber *exchangeRate;
@property (copy, nonatomic) NSString *selectedCurrency;
@property (copy, nonatomic) NSString *selectedBitcoinFormat;
@property (assign, nonatomic) satoshi_t estimatedBalance;

@end

@implementation HIProfileViewController

- (instancetype)init {
    self = [super initWithNibName:@"HIProfileViewController" bundle:nil];

    if (self) {
        self.title = NSLocalizedString(@"Profile", @"Profile view title string");
        self.iconName = @"your-profile";

        _profile = [HIProfile new];
        _infoPanel = [[HIContactInfoViewController alloc] initWithParent:self];

        [[BCClient sharedClient] addObserver:self
                                  forKeyPath:@"estimatedBalance"
                                     options:NSKeyValueObservingOptionInitial
                                     context:NULL];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateBitcoinFormat:)
                                                     name:HIPreferredFormatChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLocaleChange)
                                                     name:NSCurrentLocaleDidChangeNotification
                                                   object:nil];

        _exchangeRateService = [HIExchangeRateService sharedService];
        [_exchangeRateService addExchangeRateObserver:self];
        self.selectedCurrency = _exchangeRateService.preferredCurrency;

        _bitcoinFormatService = [HIBitcoinFormatService sharedService];
        _selectedBitcoinFormat = _bitcoinFormatService.preferredFormat;
    }

    return self;
}

- (void)dealloc {
    [[BCClient sharedClient] removeObserver:self forKeyPath:@"estimatedBalance"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_exchangeRateService removeExchangeRateObserver:self];
}

- (void)loadView {
    [super loadView];
    [_infoPanel loadView];

    self.view.layer.backgroundColor = [[NSColor hiWindowBackgroundColor] hiNativeColor];

    self.photoView.layer.borderWidth = 1.0;
    self.photoView.layer.borderColor = [[NSColor colorWithCalibratedWhite:0.88 alpha:1.0] hiNativeColor];

    [self setupCurrencyLists];
    [self updateBalance];
    [self refreshData];

    [self showControllerInContentView:_infoPanel];

}

- (void)setupCurrencyLists {
    [self.bitcoinCurrencyPopupButton addItemsWithTitles:self.bitcoinFormatService.availableFormats];
    [self.bitcoinCurrencyPopupButton selectItemWithTitle:self.selectedBitcoinFormat];
    [self.convertedCurrencyPopupButton addItemsWithTitles:self.exchangeRateService.availableCurrencies];
    [self.convertedCurrencyPopupButton selectItemWithTitle:_selectedCurrency];
}

- (void)viewWillAppear {
    [self refreshData];
    [[HINameFormatService sharedService] addObserver:self];
}

- (void)viewWillDisappear {
    [[HINameFormatService sharedService] removeObserver:self];
}

- (void)refreshData {
    self.nameLabel.stringValue = _profile.name;
    self.photoView.image = _profile.avatarImage;

    [_infoPanel configureViewForContact:_profile];
}

- (void)showControllerInContentView:(NSViewController *)controller {
    [[_contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    controller.view.frame = _contentView.bounds;
    [_contentView addSubview:controller.view];
}

- (void)updateBalance {
    self.estimatedBalance = [[BCClient sharedClient] estimatedBalance];

    [self updateBalanceLabel];
    [self updateConvertedBalanceLabel];
}

- (void)updateBalanceLabel {
    self.balanceLabel.stringValue = [self.bitcoinFormatService stringForBitcoin:self.estimatedBalance];
}

- (void)onLocaleChange {
    [self updateBalance];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == [BCClient sharedClient]) {
        if ([keyPath isEqual:@"estimatedBalance"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateBalance];
            });
        }
    }
}

#pragma mark - bitcoin format

- (void)updateBitcoinFormat:(NSNotification *)notification {
    self.selectedBitcoinFormat = [HIBitcoinFormatService sharedService].preferredFormat;
}

- (void)setSelectedBitcoinFormat:(NSString *)selectedBitcoinFormat {
    _selectedBitcoinFormat = [selectedBitcoinFormat copy];
    self.bitcoinFormatService.preferredFormat = _selectedBitcoinFormat;
    [self updateBalanceLabel];
}

#pragma mark - converted balance

- (void)setSelectedCurrency:(NSString *)selectedCurrency {
    _selectedCurrency = [selectedCurrency copy];
    self.exchangeRateService.preferredCurrency = selectedCurrency;
    [self fetchExchangeRate];
}

- (void)fetchExchangeRate {
    self.exchangeRate = nil;
    [self updateConvertedBalanceLabel];
    [self.exchangeRateService updateExchangeRateForCurrency:self.selectedCurrency];
}

- (void)updateConvertedBalanceLabel {
    if (self.exchangeRate) {
        NSDecimalNumber *convertedBalance = [self convertedAmountForBitcoinAmount:self.estimatedBalance];
        self.convertedBalanceLabel.stringValue =
            [[HICurrencyFormatService sharedService] stringWithUnitForValue:convertedBalance
                                                                 inCurrency:self.selectedCurrency];
    } else {
        self.convertedBalanceLabel.stringValue = @"?";
    }
}

- (NSDecimalNumber *)convertedAmountForBitcoinAmount:(satoshi_t)amount {
    return [[NSDecimalNumber hiDecimalNumberWithSatoshi:amount] decimalNumberByMultiplyingBy:self.exchangeRate];
}

- (IBAction)currencyChanged:(id)sender {
    self.selectedCurrency = self.convertedCurrencyPopupButton.selectedItem.title;
}

#pragma mark - HIExchangeRateObserver

- (void)exchangeRateUpdatedTo:(NSDecimalNumber *)exchangeRate
                  forCurrency:(NSString *)currency {
    if ([currency isEqual:self.selectedCurrency]) {
        self.exchangeRate = exchangeRate;
        [self updateConvertedBalanceLabel];
    }
}

#pragma mark - HINameFormatServiceObserver

- (void)nameFormatDidChange {
    [self refreshData];
}

@end
