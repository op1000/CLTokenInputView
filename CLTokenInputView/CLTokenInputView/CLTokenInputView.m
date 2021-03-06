//
//  CLTokenInputView.m
//  CLTokenInputView
//
//  Created by Rizwan Sattar on 2/24/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//

#import "CLTokenInputView.h"
#import "CLBackspaceDetectingTextField.h"
#import "CLTokenView.h"
#import "CLConstants.h"

static CGFloat const HSPACE = 0.0;
static CGFloat const TEXT_FIELD_HSPACE = 4.0; // Note: Same as CLTokenView.PADDING_X
static CGFloat const VSPACE = 4.0;
static CGFloat const MINIMUM_TEXTFIELD_WIDTH = 56.0;
static CGFloat const PADDING_TOP = 10.0;
static CGFloat const PADDING_BOTTOM = 10.0;
static CGFloat const PADDING_LEFT = 8.0;
static CGFloat const PADDING_RIGHT = 8.0;
static CGFloat const STANDARD_ROW_HEIGHT = 25.0;

static CGFloat const FIELD_MARGIN_X = 4.0; // Note: Same as CLTokenView.PADDING_X

@interface CLTokenInputView () <CLBackspaceDetectingTextFieldDelegate, CLTokenViewDelegate, UITextDropDelegate>

@property (strong, nonatomic) CL_GENERIC_MUTABLE_ARRAY(CLToken *) *tokens;
@property (strong, nonatomic) CL_GENERIC_MUTABLE_ARRAY(CLTokenView *) *tokenViews;
@property (strong, nonatomic) CLBackspaceDetectingTextField *textField;
@property (strong, nonatomic) UILabel *fieldLabel;


@property (assign, nonatomic) CGFloat intrinsicContentHeight;
@property (assign, nonatomic) CGFloat additionalTextFieldYOffset;

@property (nonatomic) BOOL hasFocus;

@end

@implementation CLTokenInputView

- (void)commonInit
{
    self.textField = [[CLBackspaceDetectingTextField alloc] initWithFrame:self.bounds];
    self.textField.nextTabResponder = self.nextTabResponder;
    self.textField.previousTabResponder = self.previousTabResponder;
    self.textField.tokenInputType = self.tokenInputType;
    self.textField.backgroundColor = [UIColor clearColor];
    self.textField.keyboardType = UIKeyboardTypeEmailAddress;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.delegate = self;
    if (@available(iOS 11.0, *)) {
        self.textField.textDropDelegate = self;
    }
    self.additionalTextFieldYOffset = 0.0;
    if (![self.textField respondsToSelector:@selector(defaultTextAttributes)]) {
        self.additionalTextFieldYOffset = 1.5;
    }
    [self.textField addTarget:self
                       action:@selector(onTextFieldDidChange:)
             forControlEvents:UIControlEventEditingChanged];
    [self addSubview:self.textField];

    self.tokens = [NSMutableArray arrayWithCapacity:20];
    self.tokenViews = [NSMutableArray arrayWithCapacity:20];

    self.fieldColor = [UIColor lightGrayColor]; 
    
    self.fieldLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    // NOTE: Explicitly not setting a font for the field label
    self.fieldLabel.textColor = self.fieldColor;
    [self addSubview:self.fieldLabel];
    self.fieldLabel.hidden = YES;

    self.intrinsicContentHeight = STANDARD_ROW_HEIGHT;
    [self repositionViews];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, MAX(44, self.intrinsicContentHeight));
}

- (BOOL)isFirstResponder
{
    return self.textField.isFirstResponder;
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
    UIKeyCommand *tabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:0 action:@selector(actionTabKeyCommandButtonPressed:)];
    UIKeyCommand *shiftTabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:UIKeyModifierShift action:@selector(actionShiftTabKeyCommandButtonPressed:)];
    return @[tabKeyCommand, shiftTabKeyCommand];
}

#pragma mark - Properties

- (void)setTokenInputType:(CLTokenInputType)recipientType
{
    _tokenInputType = recipientType;
    self.textField.tokenInputType = recipientType;
    for (CLTokenView *v in self.tokenViews) {
        v.tokenInputType = recipientType;
    }
}

- (void)setNextTabResponder:(UIView *)nextTabResponder
{
    _nextTabResponder = nextTabResponder;
    self.textField.nextTabResponder = nextTabResponder;
}

- (void)setPreviousTabResponder:(UIView *)previousTabResponder
{
    _previousTabResponder = previousTabResponder;
    self.textField.previousTabResponder = previousTabResponder;
}

#pragma mark - Actions

- (void)actionTabKeyCommandButtonPressed:(UIKeyCommand *)keyCommand
{
    if (self.textField.isFirstResponder) {
        [[self.textField nextTabResponder] becomeFirstResponder];
    }
    else {
        [self.textField becomeFirstResponder];
    }
}

- (void)actionShiftTabKeyCommandButtonPressed:(UIKeyCommand *)keyCommand
{
    if (self.textField.isFirstResponder) {
        [[self.textField previousTabResponder] becomeFirstResponder];
    }
    else {
        [self.textField becomeFirstResponder];
    }
}

#pragma mark - Tint color

- (void)tintColorDidChange
{
    for (UIView *tokenView in self.tokenViews) {
        tokenView.tintColor = self.tintColor;
    }
}

#pragma mark - Adding / Removing Tokens

- (void)addToken:(CLToken *)token clearText:(BOOL)removeText
{
    if ([self.tokens containsObject:token]) {
        return;
    }
    
    [self.tokens addObject:token];
    CLTokenView *tokenView = [[CLTokenView alloc] initWithToken:token font:self.textField.font];
    tokenView.keyboardAppearanceType = self.keyboardAppearance;
    tokenView.nextTabResponder = self.textField;
    tokenView.previousTabResponder = self.textField;
    tokenView.tokenInputType = self.tokenInputType;
    if ([self respondsToSelector:@selector(tintColor)]) {
        tokenView.tintColor = self.tintColor;
    }
    tokenView.delegate = self;
    CGSize intrinsicSize = tokenView.intrinsicContentSize;
    tokenView.frame = CGRectMake(0, 0, intrinsicSize.width, intrinsicSize.height);
    [self.tokenViews addObject:tokenView];
    [self addSubview:tokenView];
    
    if ([self.delegate respondsToSelector:@selector(tokenInputView:didAddToken:)]) {
        [self.delegate tokenInputView:self didAddToken:token];
    }
    
    if (removeText) {
        self.textField.text = @"";
        // Clearing text programmatically doesn't call this automatically
        [self onTextFieldDidChange:self.textField];
    }
    
    [self updatePlaceholderTextVisibility];
    [self repositionViews];
}

- (void)addToken:(CLToken *)token
{
    [self addToken:token clearText:YES];
}

- (void)removeToken:(CLToken *)token
{
    NSInteger index = [self.tokens indexOfObject:token];
    if (index == NSNotFound) {
        return;
    }
    [self removeTokenAtIndex:index];
}

- (void)overwriteTokens:(NSArray<CLToken *> *)tokens
{
    [self.tokens removeAllObjects];
    [self.tokenViews enumerateObjectsUsingBlock:^(CLTokenView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    [self.tokenViews removeAllObjects];
    
    [tokens enumerateObjectsUsingBlock:^(CLToken * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.tokens addObject:obj];
        CLTokenView *tokenView = [[CLTokenView alloc] initWithToken:obj font:self.textField.font];
        tokenView.keyboardAppearanceType = self.keyboardAppearance;
        tokenView.nextTabResponder = self.textField;
        tokenView.previousTabResponder = self.textField;
        tokenView.tokenInputType = self.tokenInputType;
        if ([self respondsToSelector:@selector(tintColor)]) {
            tokenView.tintColor = self.tintColor;
        }
        tokenView.delegate = self;
        CGSize intrinsicSize = tokenView.intrinsicContentSize;
        tokenView.frame = CGRectMake(0, 0, intrinsicSize.width, intrinsicSize.height);
        [self.tokenViews addObject:tokenView];
        [self addSubview:tokenView];
    }];

    [self updatePlaceholderTextVisibility];
    [self repositionViews];
}

- (void)removeTokenAtIndex:(NSInteger)index
{
    if (index == NSNotFound) {
        return;
    }
    CLTokenView *tokenView = self.tokenViews[index];
    [tokenView removeFromSuperview];
    [self.tokenViews removeObjectAtIndex:index];
    CLToken *removedToken = self.tokens[index];
    [self.tokens removeObjectAtIndex:index];
    if ([self.delegate respondsToSelector:@selector(tokenInputView:didRemoveToken:)]) {
        [self.delegate tokenInputView:self didRemoveToken:removedToken];
    }
    [self updatePlaceholderTextVisibility];
    [self repositionViews];
}

- (NSArray *)allTokens
{
    return [self.tokens copy];
}

- (CLToken *)tokenizeTextfieldText
{
    CLToken *token = nil;
    NSString *text = self.textField.text;
    if (text.length > 0 &&
        [self.delegate respondsToSelector:@selector(tokenInputView:tokenForText:)]) {
        token = [self.delegate tokenInputView:self tokenForText:text];
        if (token != nil) {
            [self addToken:token];
            self.textField.text = @"";
            [self onTextFieldDidChange:self.textField];
        }
    }
    return token;
}

- (void)editCancelAndClearText
{
    self.textField.text = @"";
    // Clearing text programmatically doesn't call this automatically
    [self onTextFieldDidChange:self.textField];
}

- (BOOL)isSelected
{
    for (CLTokenView *v in self.tokenViews) {
        if (v.selected) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Updating/Repositioning Views

- (void)repositionViews
{
    CGRect bounds = self.bounds;
    CGFloat rightBoundary = CGRectGetWidth(bounds) - PADDING_RIGHT;
    CGFloat firstLineRightBoundary = rightBoundary;

    CGFloat curX = PADDING_LEFT;
    CGFloat curY = PADDING_TOP;
    CGFloat totalHeight = STANDARD_ROW_HEIGHT;
    BOOL isOnFirstLine = YES;

    // Position field view (if set)
    if (self.fieldView) {
        CGRect fieldViewRect = self.fieldView.frame;
        fieldViewRect.origin.x = curX + FIELD_MARGIN_X;
        fieldViewRect.origin.y = curY + ((STANDARD_ROW_HEIGHT - CGRectGetHeight(fieldViewRect))/2.0);
        self.fieldView.frame = fieldViewRect;

        curX = CGRectGetMaxX(fieldViewRect) + FIELD_MARGIN_X;
    }

    // Position field label (if field name is set)
    if (!self.fieldLabel.hidden) {
        CGSize labelSize = self.fieldLabel.intrinsicContentSize;
        CGRect fieldLabelRect = CGRectZero;
        fieldLabelRect.size = labelSize;
        fieldLabelRect.origin.x = curX + FIELD_MARGIN_X;
        fieldLabelRect.origin.y = curY + ((STANDARD_ROW_HEIGHT-CGRectGetHeight(fieldLabelRect))/2.0);
        self.fieldLabel.frame = fieldLabelRect;

        curX = CGRectGetMaxX(fieldLabelRect) + FIELD_MARGIN_X;
    }

    // Position accessory view (if set)
    if (self.accessoryView) {
        CGRect accessoryRect = self.accessoryView.frame;
        accessoryRect.origin.x = CGRectGetWidth(bounds) - PADDING_RIGHT - CGRectGetWidth(accessoryRect);
        self.accessoryView.frame = accessoryRect;

        firstLineRightBoundary = CGRectGetMinX(accessoryRect) - HSPACE;
    }

    // Position token views
    CGRect tokenRect = CGRectNull;
    for (UIView *tokenView in self.tokenViews) {
        tokenRect = tokenView.frame;

        CGFloat tokenBoundary = isOnFirstLine ? firstLineRightBoundary : rightBoundary;
        if (curX + CGRectGetWidth(tokenRect) > tokenBoundary) {
            // Need a new line
            curX = PADDING_LEFT;
            curY += STANDARD_ROW_HEIGHT+VSPACE;
            totalHeight += STANDARD_ROW_HEIGHT;
            isOnFirstLine = NO;
        }

        tokenRect.origin.x = curX;
        // Center our tokenView vertially within STANDARD_ROW_HEIGHT
        tokenRect.origin.y = curY + ((STANDARD_ROW_HEIGHT-CGRectGetHeight(tokenRect))/2.0);
        tokenView.frame = tokenRect;

        curX = CGRectGetMaxX(tokenRect) + HSPACE;
    }

    // Always indent textfield by a little bit
    curX += TEXT_FIELD_HSPACE;
    CGFloat textBoundary = isOnFirstLine ? firstLineRightBoundary : rightBoundary;
    CGFloat availableWidthForTextField = textBoundary - curX;
    if (availableWidthForTextField < MINIMUM_TEXTFIELD_WIDTH) {
        isOnFirstLine = NO;
        // If in the future we add more UI elements below the tokens,
        // isOnFirstLine will be useful, and this calculation is important.
        // So leaving it set here, and marking the warning to ignore it
#pragma unused(isOnFirstLine)
        curX = PADDING_LEFT + TEXT_FIELD_HSPACE;
        curY += STANDARD_ROW_HEIGHT+VSPACE;
        totalHeight += STANDARD_ROW_HEIGHT;
        // Adjust the width
        availableWidthForTextField = rightBoundary - curX;
    }

    CGRect textFieldRect = self.textField.frame;
    textFieldRect.origin.x = curX;
    textFieldRect.origin.y = curY + self.additionalTextFieldYOffset;
    textFieldRect.size.width = availableWidthForTextField;
    textFieldRect.size.height = STANDARD_ROW_HEIGHT;
    self.textField.frame = textFieldRect;

    CGFloat oldContentHeight = self.intrinsicContentHeight;
    self.intrinsicContentHeight = MAX(totalHeight, CGRectGetMaxY(textFieldRect)+PADDING_BOTTOM);
    [self invalidateIntrinsicContentSize];

    if (oldContentHeight != self.intrinsicContentHeight) {
        if ([self.delegate respondsToSelector:@selector(tokenInputView:didChangeHeightTo:)]) {
            [self.delegate tokenInputView:self didChangeHeightTo:self.intrinsicContentSize.height];
        }
    }
    [self setNeedsDisplay];
}

- (void)updatePlaceholderTextVisibility
{
    if (self.tokens.count > 0) {
        self.textField.placeholder = nil;
    } else {
        self.textField.placeholder = self.placeholderText;
        if (self.placeholderTextColor) {
            self.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.textField.placeholder attributes:@{NSForegroundColorAttributeName : self.placeholderTextColor}];
        }
    }
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    [self repositionViews];
}


#pragma mark - CLBackspaceDetectingTextFieldDelegate

- (void)textFieldDidDeleteBackwards:(UITextField *)textField
{
    // Delay selecting the next token slightly, so that on iOS 8
    // the deleteBackward on CLTokenView is not called immediately,
    // causing a double-delete
    if (textField.text.length == 0) {
        CLTokenView *tokenView = self.tokenViews.lastObject;
        if (tokenView != nil && tokenView.selected == NO) {
            [self selectTokenView:tokenView animated:YES];
            [self.textField resignFirstResponder];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    self.hasFocus = YES;
    if ([self.delegate respondsToSelector:@selector(tokenInputVieShouldBeginEditing:)]) {
        return [self.delegate tokenInputVieShouldBeginEditing:self];
    }
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenInputViewDidBeginEditing:)]) {
        [self.delegate tokenInputViewDidBeginEditing:self];
    }
    ((CLTokenView *)self.tokenViews.lastObject).hideUnselectedComma = NO;
    [self unselectAllTokenViewsAnimated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenInputViewDidEndEditing:)]
        && self.isSelected == NO) {
        [self.delegate tokenInputViewDidEndEditing:self];
    }
    ((CLTokenView *)self.tokenViews.lastObject).hideUnselectedComma = YES;
    self.hasFocus = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self tokenizeTextfieldText];
    BOOL shouldDoDefaultBehavior = NO;
    if ([self.delegate respondsToSelector:@selector(tokenInputViewShouldReturn:)]) {
        shouldDoDefaultBehavior = [self.delegate tokenInputViewShouldReturn:self];
    }
    return shouldDoDefaultBehavior;
}

- (BOOL)                    textField:(UITextField *)textField
        shouldChangeCharactersInRange:(NSRange)range
                    replacementString:(NSString *)string
{
    if (string.length > 0 && [self.tokenizationCharacters member:string]) {
        [self tokenizeTextfieldText];
        // Never allow the change if it matches at token
        return NO;
    }
    if (textField.text.length == 0 && string.length > 0) {
        if ([self.delegate respondsToSelector:@selector(tokenInputViewWillStartInputText:)]) {
            [self.delegate tokenInputViewWillStartInputText:self];
        }
    }
    return YES;
}


#pragma mark - Text Field Changes

- (void)onTextFieldDidChange:(id)sender
{
    if (self.textField.text.length == 0) {
        if ([self.delegate respondsToSelector:@selector(tokenInputViewDidEndInputText:)]) {
            [self.delegate tokenInputViewDidEndInputText:self];
        }
    }
    if ([self.delegate respondsToSelector:@selector(tokenInputView:didChangeText:)]) {
        [self.delegate tokenInputView:self didChangeText:self.textField.text];
    }
}

#pragma mark - Text Field Customization

- (void)setKeyboardType:(UIKeyboardType)keyboardType
{
    _keyboardType = keyboardType;
    self.textField.keyboardType = _keyboardType;
}

- (void)setAutocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
{
    _autocapitalizationType = autocapitalizationType;
    self.textField.autocapitalizationType = _autocapitalizationType;
}

- (void)setAutocorrectionType:(UITextAutocorrectionType)autocorrectionType
{
    _autocorrectionType = autocorrectionType;
    self.textField.autocorrectionType = _autocorrectionType;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance
{
    _keyboardAppearance = keyboardAppearance;
    self.textField.keyboardAppearance = _keyboardAppearance;
}


#pragma mark - Measurements (text field offset, etc.)

- (CGFloat)textFieldDisplayOffset
{
    // Essentially the textfield's y with PADDING_TOP
    return CGRectGetMinY(self.textField.frame) - PADDING_TOP;
}


#pragma mark - Textfield text


- (NSString *)text
{
    return self.textField.text;
}


#pragma mark - CLTokenViewDelegate

- (void)tokenViewDidRequestDelete:(CLTokenView *)tokenView replaceWithText:(NSString *)replacementText
{
    // First, refocus the text field
    [self.textField becomeFirstResponder];
    if (replacementText.length > 0) {
        self.textField.text = replacementText;
    }
    // Then remove the view from our data
    NSInteger index = [self.tokenViews indexOfObject:tokenView];
    if (index == NSNotFound) {
        return;
    }
    [self removeTokenAtIndex:index];
}

- (void)tokenViewDidRequestSelection:(CLTokenView *)tokenView
{
    if (self.textField.text.length > 0) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(tokenInputVieShouldBeginEditing:)]
        && self.hasFocus == NO && self.isSelected == NO) {
        [self.delegate tokenInputVieShouldBeginEditing:self];
    }
    BOOL oldSelected = tokenView.selected;
    [self selectTokenView:tokenView animated:YES];
    if (oldSelected && tokenView.selected &&
        [self.delegate respondsToSelector:@selector(tokenInputView:didReselectToken:)]) {
        NSInteger index = [self.tokenViews indexOfObject:tokenView];
        if (index != NSNotFound) {
            [self.delegate tokenInputView:self didReselectToken:self.tokens[index]];
        }
    }
    if ([self.delegate respondsToSelector:@selector(tokenInputView:didSelectToken:)]) {
        NSInteger index = [self.tokenViews indexOfObject:tokenView];
        if (index != NSNotFound) {
            [self.delegate tokenInputView:self didSelectToken:self.tokens[index]];
        }
    }
}

- (void)tokenViewReleaseFocus:(CLTokenView *)tokenView
{
    if ([self.delegate respondsToSelector:@selector(tokenInputViewDidEndEditing:)]
        && self.hasFocus == NO) {
        [self.delegate tokenInputViewDidEndEditing:self];
    }
}

#pragma mark - Token selection

- (void)selectTokenView:(CLTokenView *)tokenView animated:(BOOL)animated
{
    [tokenView setSelected:YES animated:animated];
    for (CLTokenView *otherTokenView in self.tokenViews) {
        if (otherTokenView != tokenView) {
            [otherTokenView setSelected:NO animated:animated];
        }
    }
}

- (void)unselectAllTokenViewsAnimated:(BOOL)animated
{
    for (CLTokenView *tokenView in self.tokenViews) {
        [tokenView setSelected:NO animated:animated];
    }
}


#pragma mark - Editing

- (BOOL)isEditing
{
    return self.textField.editing;
}


- (void)beginEditing
{
    [self.textField becomeFirstResponder];
    [self unselectAllTokenViewsAnimated:NO];
}


- (void)endEditing
{
    // NOTE: We used to check if .isFirstResponder
    // and then resign first responder, but sometimes
    // we noticed that it would be the first responder,
    // but still return isFirstResponder=NO. So always
    // attempt to resign without checking.
    [self.textField resignFirstResponder];
}

#pragma mark - First Responder (needed to capture keyboard)

-(BOOL)canBecomeFirstResponder
{
    return YES;
}

-(BOOL)resignFirstResponder
{
    // NOTE: [super resignFirstResponder]를 호출하면 keyboard notification을 등록한 모든 객체한테 호출이되서 이상한 UI 현상이 발생할 수 있으므로 [super resignFirstResponder]를 호출하지 않는다.
    [self.textField resignFirstResponder];
    return YES;
}

- (BOOL)becomeFirstResponder
{
    return [self.textField becomeFirstResponder];
}

- (void)refreshColor
{
    [self.tokens enumerateObjectsUsingBlock:^(CLToken * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.tokenViews.count > idx) {
            if (obj.tintColor == nil) {
                self.tokenViews[idx].tintColor = [UIColor colorWithRed:0.0f/255.0f green:122.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            }
            else {
                self.tokenViews[idx].tintColor = obj.tintColor;
            }
        }
    }];
}

- (nullable CLToken *)selectPreviousToken
{
    if (self.tokens.count == 0) {
        return nil;
    }
    if (self.textField.isFirstResponder) {
        CLTokenView *tokenToReturn = self.tokenViews.lastObject;
        if (tokenToReturn) {
            [tokenToReturn setSelected:YES animated:YES];
        }
        [self.textField resignFirstResponder];
        return tokenToReturn.token;
    }
    else {
        CLTokenView *tokenToReturn = nil;
        for (CLTokenView *v in self.tokenViews) {
            if (v.selected) {
                NSInteger index = [self.tokenViews indexOfObject:v];
                if (index > 0) {
                    tokenToReturn = self.tokenViews[index - 1];
                    [v setSelected:NO animated:YES];
                }
                else {
                    tokenToReturn = nil;
                }
                break;
            }
        }
        if (tokenToReturn) {
            [tokenToReturn setSelected:YES animated:YES];
        }
        return tokenToReturn.token;
    }
}

- (nullable CLToken *)selectNextToken
{
    if (self.tokens.count == 0) {
        return nil;
    }
    CLTokenView *tokenToReturn = nil;
    for (CLTokenView *v in self.tokenViews) {
        if (v.selected) {
            NSInteger index = [self.tokenViews indexOfObject:v];
            if (index + 1 < self.tokenViews.count) {
                tokenToReturn = self.tokenViews[index + 1];
                [v setSelected:NO animated:YES];
            }
            else {
                tokenToReturn = nil;
            }
            break;
        }
    }
    if (tokenToReturn) {
        [tokenToReturn setSelected:YES animated:YES];
        return tokenToReturn.token;
    }
    else {
        [self.textField becomeFirstResponder];
        return nil;
    }
}

#pragma mark - (Optional Views)

- (void)setFieldName:(NSString *)fieldName
{
    if (_fieldName == fieldName) {
        return;
    }
    NSString *oldFieldName = _fieldName;
    _fieldName = fieldName;

    self.fieldLabel.text = _fieldName;
    [self.fieldLabel invalidateIntrinsicContentSize];
    BOOL showField = (_fieldName.length > 0);
    self.fieldLabel.hidden = !showField;
    if (showField && !self.fieldLabel.superview) {
        [self addSubview:self.fieldLabel];
    } else if (!showField && self.fieldLabel.superview) {
        [self.fieldLabel removeFromSuperview];
    }

    if (oldFieldName == nil || ![oldFieldName isEqualToString:fieldName]) {
        [self repositionViews];
    }
}

- (void)setFieldColor:(UIColor *)fieldColor {
    _fieldColor = fieldColor;
    self.fieldLabel.textColor = _fieldColor;
}

- (void)setFieldView:(UIView *)fieldView
{
    if (_fieldView == fieldView) {
        return;
    }
    [_fieldView removeFromSuperview];
    _fieldView = fieldView;
    if (_fieldView != nil) {
        [self addSubview:_fieldView];
    }
    [self repositionViews];
}

- (void)setPlaceholderText:(NSString *)placeholderText
{
    if (_placeholderText == placeholderText) {
        return;
    }
    _placeholderText = placeholderText;
    [self updatePlaceholderTextVisibility];
}

- (void)setPlaceholderTextColor:(UIColor *)placeholderTextColor
{
    if (_placeholderTextColor == placeholderTextColor) {
        return;
    }
    _placeholderTextColor = placeholderTextColor;
    [self updatePlaceholderTextVisibility];
}

- (void)setAccessoryView:(UIView *)accessoryView
{
    if (_accessoryView == accessoryView) {
        return;
    }
    [_accessoryView removeFromSuperview];
    _accessoryView = accessoryView;

    if (_accessoryView != nil) {
        [self addSubview:_accessoryView];
    }
    [self repositionViews];
}


#pragma mark - Drawing

- (void)setDrawBottomBorder:(BOOL)drawBottomBorder
{
    if (_drawBottomBorder == drawBottomBorder) {
        return;
    }
    _drawBottomBorder = drawBottomBorder;
    [self setNeedsDisplay];
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    if (self.drawBottomBorder) {

        CGContextRef context = UIGraphicsGetCurrentContext();
        CGRect bounds = self.bounds;
        CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
        CGContextSetLineWidth(context, 0.5);

        CGContextMoveToPoint(context, 0, bounds.size.height);
        CGContextAddLineToPoint(context, CGRectGetWidth(bounds), bounds.size.height);
        CGContextStrokePath(context);
    }
}

#pragma mark -  UITextDropDelegate

- (UITextDropEditability)textDroppableView:(UIView<UITextDroppable> *)textDroppableView willBecomeEditableForDrop:(id<UITextDropRequest>)drop API_AVAILABLE(ios(11.0))
{
    return UITextDropEditabilityNo;
}

- (UITextDropProposal*)textDroppableView:(UIView<UITextDroppable> *)textDroppableView proposalForDrop:(id<UITextDropRequest>)drop API_AVAILABLE(ios(11.0))
{
    if (@available(iOS 11.0, *)) {
        UITextDropProposal *proposal = [[UITextDropProposal alloc] initWithDropOperation:UIDropOperationForbidden];
        return proposal;
    }
    return nil;
}

@end
