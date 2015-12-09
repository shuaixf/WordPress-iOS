#import "MenuItemsStackView.h"
#import "Menu.h"
#import "MenuItem.h"
#import "WPStyleGuide.h"
#import "MenuItemsStackableView.h"
#import "MenuItemView.h"
#import "MenuItemInsertionView.h"
#import "MenusDesign.h"
#import "MenuItemsVisualOrderingView.h"
#import "MenuItemEditingView.h"

@interface MenuItemsStackView () <MenuItemsStackableViewDelegate, MenuItemViewDelegate, MenuItemInsertionViewDelegate, MenuItemsVisualOrderingViewDelegate>

@property (nonatomic, weak) IBOutlet UIStackView *stackView;
@property (nonatomic, strong) NSMutableSet *itemViews;

@property (nonatomic, strong) NSMutableSet *insertionViews;
@property (nonatomic, strong) MenuItemView *itemViewForInsertionToggling;
@property (nonatomic, assign) BOOL isEditingForItemViewInsertion;

@property (nonatomic, assign) CGPoint touchesBeganLocation;
@property (nonatomic, assign) CGPoint touchesMovedLocation;
@property (nonatomic, assign) BOOL showingTouchesOrdering;
@property (nonatomic, strong) MenuItemView *itemViewForOrdering;
@property (nonatomic, strong) MenuItemsVisualOrderingView *visualOrderingView;

@property (nonatomic, strong) MenuItemEditingView *editingView;

@end

@implementation MenuItemsStackView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.alignment = UIStackViewAlignmentTop;
    self.stackView.spacing = 0.0;
    
    self.touchesBeganLocation = CGPointZero;
    self.touchesMovedLocation = CGPointZero;
    
    [self setupStyling];
}

- (void)setupStyling
{
    self.backgroundColor = [WPStyleGuide lightGrey];
}

- (void)setMenu:(Menu *)menu
{
    if(_menu != menu) {
        _menu = menu;
        [self reloadItemViews];
    }
}

- (void)reloadItemViews
{
    for(MenuItemsStackableView *stackableView in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:stackableView];
        [stackableView removeFromSuperview];
    }
    
    self.itemViews = [NSMutableSet set];
    self.insertionViews = nil;
    
    MenuItemView *lastItemView = nil;
    for(MenuItem *item in self.menu.items) {
        
        MenuItemView *itemView = [[MenuItemView alloc] init];
        itemView.delegate = self;
        // set up ordering to help with any drawing
        itemView.item = item;
        itemView.indentationLevel = 0;
        
        MenuItem *parentItem = item.parent;
        while (parentItem) {
            itemView.indentationLevel++;
            parentItem = parentItem.parent;
        }
        
        NSLayoutConstraint *heightConstraint = [itemView.heightAnchor constraintEqualToConstant:MenuItemsStackableViewDefaultHeight];
        heightConstraint.priority = UILayoutPriorityDefaultHigh;
        heightConstraint.active = YES;
        
        [self.itemViews addObject:itemView];
        [self.stackView addArrangedSubview:itemView];
        
        [itemView.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
        lastItemView = itemView;
    }
}

- (MenuItemInsertionView *)addNewInsertionViewWithType:(MenuItemInsertionViewType)type forItemView:(MenuItemView *)itemView
{
    NSInteger index = [self.stackView.arrangedSubviews indexOfObject:itemView];
    MenuItemInsertionView *insertionView = [[MenuItemInsertionView alloc] init];
    insertionView.delegate = self;
    insertionView.type = type;
    
    switch (type) {
        case MenuItemInsertionViewTypeAbove:
            insertionView.indentationLevel = itemView.indentationLevel;
            break;
        case MenuItemInsertionViewTypeBelow:
            insertionView.indentationLevel = itemView.indentationLevel;
            index++;
            break;
        case MenuItemInsertionViewTypeChild:
            insertionView.indentationLevel = itemView.indentationLevel + 1;
            index += 2;
            break;
    }
    
    NSLayoutConstraint *heightConstraint = [insertionView.heightAnchor constraintEqualToConstant:MenuItemsStackableViewDefaultHeight];
    heightConstraint.priority = UILayoutPriorityDefaultHigh;
    heightConstraint.active = YES;
    
    [self.insertionViews addObject:insertionView];
    [self.stackView insertArrangedSubview:insertionView atIndex:index];
    
    [insertionView.widthAnchor constraintEqualToAnchor:self.stackView.widthAnchor].active = YES;
    
    return insertionView;
}

- (void)insertInsertionItemViewsAroundItemView:(MenuItemView *)toggledItemView
{
    self.itemViewForInsertionToggling = toggledItemView;
    toggledItemView.showsCancelButtonOption = YES;
    toggledItemView.showsEditingButtonOptions = NO;
    
    self.insertionViews = [NSMutableSet setWithCapacity:3];
    [self addNewInsertionViewWithType:MenuItemInsertionViewTypeAbove forItemView:toggledItemView];
    [self addNewInsertionViewWithType:MenuItemInsertionViewTypeBelow forItemView:toggledItemView];
    [self addNewInsertionViewWithType:MenuItemInsertionViewTypeChild forItemView:toggledItemView];
}

- (void)insertItemInsertionViewsAroundItemView:(MenuItemView *)toggledItemView animated:(BOOL)animated
{
    if(self.isEditingForItemViewInsertion) {
        [self removeItemInsertionViews:NO];
    }
    
    self.isEditingForItemViewInsertion = YES;
    
    CGRect previousRect = toggledItemView.frame;
    CGRect updatedRect = toggledItemView.frame;
    
    [self insertInsertionItemViewsAroundItemView:toggledItemView];
    
    if(!animated) {
        return;
    }
    
    // since we are adding content above the toggledItemView, the toggledItemView (focus) will move downwards with the updated content size
    updatedRect.origin.y += MenuItemsStackableViewDefaultHeight;
    
    for(MenuItemInsertionView *insertionView in self.insertionViews) {
        insertionView.hidden = YES;
        insertionView.alpha = 0.0;
    }
    
    [UIView animateWithDuration:0.3 delay:0.0 options:0 animations:^{
        
        for(MenuItemInsertionView *insertionView in self.insertionViews) {
            insertionView.hidden = NO;
            insertionView.alpha = 1.0;
        }
        // inform the delegate to handle this content change based on the rect we are focused on
        // a delegate will likely scroll the content with the size change
        [self.delegate itemsViewAnimatingContentSizeChanges:self focusedRect:previousRect updatedFocusRect:updatedRect];
        
    } completion:^(BOOL finished) {
        
    }];
}

- (void)removeItemInsertionViews
{
    for(MenuItemInsertionView *insertionView in self.insertionViews) {
        [self.stackView removeArrangedSubview:insertionView];
        [insertionView removeFromSuperview];
    }
    
    self.insertionViews = nil;
    self.itemViewForInsertionToggling = nil;
}

- (void)removeItemInsertionViews:(BOOL)animated
{
    self.isEditingForItemViewInsertion = NO;
    self.itemViewForInsertionToggling.showsCancelButtonOption = NO;
    self.itemViewForInsertionToggling.showsEditingButtonOptions = YES;
    
    if(!animated) {
        [self removeItemInsertionViews];
        return;
    }
    
    CGRect previousRect = self.itemViewForInsertionToggling.frame;
    CGRect updatedRect = previousRect;
    // since we are removing content above the toggledItemView, the toggledItemView (focus) will move upwards with the updated content size
    updatedRect.origin.y -= MenuItemsStackableViewDefaultHeight;
    
    [UIView animateWithDuration:0.3 delay:0.0 options:0 animations:^{
        
        for(MenuItemInsertionView *insertionView in self.insertionViews) {
            insertionView.hidden = YES;
            insertionView.alpha = 0.0;
        }
        
        // inform the delegate to handle this content change based on the rect we are focused on
        // a delegate will likely scroll the content with the size change
        [self.delegate itemsViewAnimatingContentSizeChanges:self focusedRect:previousRect updatedFocusRect:updatedRect];
        
    } completion:^(BOOL finished) {
        
        [self removeItemInsertionViews];
    }];
}

- (MenuItemView *)itemViewForItem:(MenuItem *)item
{
    MenuItemView *itemView = nil;
    for(MenuItemView *arrangedItemView in self.itemViews) {
        if(arrangedItemView.item == item) {
            itemView = arrangedItemView;
            break;
        }
    }
    return itemView;
}

#pragma mark - touches

- (void)resetTouchesMovedObservationVectorX
{
    CGPoint reset = CGPointZero;
    reset.x = self.touchesMovedLocation.x;
    reset.y = self.touchesBeganLocation.y;
    self.touchesBeganLocation = reset;
}

- (void)resetTouchesMovedObservationVectorY
{
    CGPoint reset = CGPointZero;
    reset.y = self.touchesMovedLocation.y;
    reset.x = self.touchesBeganLocation.x;
    self.touchesBeganLocation = reset;
}

- (void)updateWithTouchesStarted:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint location = [[touches anyObject] locationInView:self];

    self.touchesBeganLocation = location;
    
    if(self.isEditingForItemViewInsertion) {
        return;
    }
    
    for(MenuItemView *itemView in self.itemViews) {
        if(CGRectContainsPoint(itemView.frame, location)) {
            [self beginOrdering:itemView];
            break;
        }
    }
}

- (void)updateWithTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint location = [[touches anyObject] locationInView:self];
    
    CGPoint startLocation = self.touchesBeganLocation;
    self.touchesMovedLocation = location;
    CGPoint vector = CGPointZero;
    vector.x = location.x - startLocation.x;
    vector.y = location.y - startLocation.y;
    
    if(self.isEditingForItemViewInsertion) {
        return;
    }
    
    [self showOrdering];
    [self orderingTouchesMoved:touches withEvent:event vector:vector];
}

- (void)updateWithTouchesStopped:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.touchesBeganLocation = CGPointZero;
    self.touchesMovedLocation = CGPointZero;
    [self endReordering];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self updateWithTouchesStarted:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self updateWithTouchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self updateWithTouchesStopped:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self updateWithTouchesStopped:touches withEvent:event];
}

#pragma mark - ordering

- (void)beginOrdering:(MenuItemView *)orderingView
{
    self.itemViewForOrdering = orderingView;
    [self prepareVisualOrderingViewWithItemView:orderingView];
    
    [self.delegate itemsView:self prefersScrollingEnabled:NO];
}

- (void)showOrdering
{
    if(!self.showingTouchesOrdering) {
        self.showingTouchesOrdering = YES;
        [self showVisualOrderingView];
        [self toggleOrderingPlaceHolder:YES forItemViewsWithSelectedItemView:self.itemViewForOrdering];
    }
}

- (void)hideOrdering
{
    self.showingTouchesOrdering = NO;
    [self toggleOrderingPlaceHolder:NO forItemViewsWithSelectedItemView:self.itemViewForOrdering];
    [self hideVisualOrderingView];
}

- (void)endReordering
{
    // cleanup
    
    [self hideOrdering];
    self.itemViewForOrdering = nil;
    [self.delegate itemsView:self prefersScrollingEnabled:YES];
}

- (void)orderingTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event vector:(CGPoint)vector
{
    if(!self.itemViewForOrdering) {
        return;
    }
    
    const CGPoint touchPoint = [[touches anyObject] locationInView:self];
    MenuItemView *selectedItemView = self.itemViewForOrdering;
    
    MenuItem *selectedItem = selectedItemView.item;
    
    //// horiztonal indentation detection (child relationships)
    //// detect if the user is moving horizontally to the right or left to change the indentation
    
    // first check to see if we should pay attention to touches that might signal a change in indentation
    const BOOL detectedHorizontalOrderingTouches = fabs(vector.x) > ((selectedItemView.frame.size.width * 5.0) / 100); // a travel of x% should be considered for updating relationships
    BOOL modelUpdated = NO;
    
    [self.visualOrderingView updateVisualOrderingWithTouchLocation:touchPoint vector:vector];
    
    if(detectedHorizontalOrderingTouches) {
        
        NSOrderedSet *orderedItems = self.menu.items;
        NSUInteger selectedItemIndex = [orderedItems indexOfObject:selectedItem];
        
        // check if not first item in order
        if(selectedItemIndex > 0) {
            // detect the child/parent relationship changes and update the model
            if(vector.x > 0) {
                // trying to make a child
                MenuItem *previousItem = [orderedItems objectAtIndex:selectedItemIndex - 1];
                MenuItem *parent = previousItem;
                MenuItem *newParent = nil;
                while (parent) {
                    if(parent == selectedItem.parent) {
                        break;
                    }
                    newParent = parent;
                    parent = parent.parent;
                }
                
                if(newParent) {
                    selectedItem.parent = newParent;
                    modelUpdated = YES;
                }
                
            }else {
                if(selectedItem.parent) {
                    
                    MenuItem *lastChildItem = nil;
                    NSUInteger parentIndex = [orderedItems indexOfObject:selectedItem.parent];
                    for(NSUInteger i = parentIndex + 1; i < orderedItems.count; i++) {
                        MenuItem *child = [orderedItems objectAtIndex:i];
                        if(child.parent == selectedItem.parent) {
                            lastChildItem = child;
                        }
                        if(![lastChildItem isDescendantOfItem:selectedItem.parent]) {
                            break;
                        }
                    }
                    
                    // only the lastChildItem can move up the tree, otherwise it would break the visual child/parent relationship
                    if(selectedItem == lastChildItem) {
                        // try to move up the parent tree
                        MenuItem *parent = selectedItem.parent.parent;
                        selectedItem.parent = parent;
                        modelUpdated = YES;
                    }
                }
            }
        }
        
        // reset the vector to observe the next delta of interest
        [self resetTouchesMovedObservationVectorX];
    }
    
    if(!CGRectContainsPoint(selectedItemView.frame, touchPoint)) {
        
        //// if the touch is over a different item, detect which item to replace the ordering with
        
        for(MenuItemView *itemView in self.itemViews) {
            // enumerate the itemViews lists since we don't care about other views in the stackView.arrangedSubviews list
            if(itemView == selectedItemView) {
                continue;
            }
            // detect if the touch within a padded inset of an itemView under the touchPoint
            const CGRect orderingDetectionRect = CGRectInset(itemView.frame, 10.0, 10.0);
            if(CGRectContainsPoint(orderingDetectionRect, touchPoint)) {
                
                // reorder the model if needed or available
                BOOL orderingUpdate = [self handleOrderingTouchForItemView:selectedItemView withOtherItemView:itemView touchLocation:touchPoint];
                if(orderingUpdate) {
                    modelUpdated = YES;
                }
                break;
            }
        }
    }
    
    // update the views based on the model changes
    if(modelUpdated) {
        
        for(UIView *arrangedView in self.stackView.arrangedSubviews) {
            if(![arrangedView isKindOfClass:[MenuItemView class]]) {
                continue;
            }
            
            MenuItemView *itemView = (MenuItemView *)arrangedView;
            itemView.indentationLevel = 0;
            
            MenuItem *parentItem = itemView.item.parent;
            while (parentItem) {
                itemView.indentationLevel++;
                parentItem = parentItem.parent;
            }
        }
        
        [self.visualOrderingView updateForVisualOrderingMenuItemsModelChange];
    }
}

- (BOOL)handleOrderingTouchForItemView:(MenuItemView *)itemView withOtherItemView:(MenuItemView *)otherItemView touchLocation:(CGPoint)touchLocation
{
    // ordering may may reflect the user wanting to move an item to before or after otherItem
    // ordering may reflect the user wanting to move an item to be a child of the parent of otherItem
    // ordering may reflect the user wanting to move an item out of a child stack, or up the parent tree to the next parent
    
    if(itemView == otherItemView) {
        return NO;
    }
    
    MenuItem *item = itemView.item;
    MenuItem *otherItem = otherItemView.item;

    // can't order a ancestor within a descendant
    if([otherItem isDescendantOfItem:item]) {
        return NO;
    }
    
    BOOL updated = NO;
    
    NSMutableOrderedSet *orderedItems = [NSMutableOrderedSet orderedSetWithOrderedSet:self.menu.items];
    
    const BOOL itemIsOrderedBeforeOtherItem = [orderedItems indexOfObject:item] < [orderedItems indexOfObject:otherItem];
    
    const BOOL orderingTouchesBeforeOtherItem = touchLocation.y < CGRectGetMidY(otherItemView.frame);
    const BOOL orderingTouchesAfterOtherItem = !orderingTouchesBeforeOtherItem; // using additional BOOL for readability
    
    void (^moveItemAndDescendantsOrderingWithOtherItem)(BOOL) = ^ (BOOL afterOtherItem) {
        
        // get the item and its descendants
        NSMutableArray *movingItems = [NSMutableArray array];
        for(NSUInteger i = [orderedItems indexOfObject:item]; i < orderedItems.count; i++) {
            MenuItem *orderedItem = [orderedItems objectAtIndex:i];
            if(orderedItem != item && ![orderedItem isDescendantOfItem:item]) {
                break;
            }
            [movingItems addObject:orderedItem];
        }
        
        [orderedItems removeObjectsInArray:movingItems];
        
        // insert the items in new position
        NSUInteger otherItemIndex = [orderedItems indexOfObject:otherItem];
        NSUInteger insertionIndex = afterOtherItem ? otherItemIndex + 1 : otherItemIndex;
        
        [orderedItems insertObjects:movingItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertionIndex, movingItems.count)]];
    };
    
    if(itemIsOrderedBeforeOtherItem) {
        // descending in ordering
        
        if(orderingTouchesBeforeOtherItem) {
            // trying to move up the parent tree
            
            if(item.parent != otherItem.parent) {
                if([self nextAvailableItemForOrderingAfterItem:item] == otherItem) {
                    // take the parent of the otherItem, or nil
                    item.parent = otherItem.parent;
                    updated = YES;
                }
            }
            
        }else if(orderingTouchesAfterOtherItem) {
            // trying to order the item after the otherItem
            
            if(otherItem.children.count) {
                // if ordering after a parent, we need to become a child
                item.parent = otherItem;
            }else {
                // assuming the item will take the parent of the otherItem's parent, or nil
                item.parent = otherItem.parent;
            }
            
            moveItemAndDescendantsOrderingWithOtherItem(YES);
            
            updated = YES;
        }
        
    }else {
        // ascending in ordering
        
        if(orderingTouchesBeforeOtherItem) {
            // trying to order the item before the otherItem
            
            // assuming the item will become the parent of the otherItem's parent, or nil
            item.parent = otherItem.parent;
            
            moveItemAndDescendantsOrderingWithOtherItem(NO);
            
            updated = YES;
            
        }else if(orderingTouchesAfterOtherItem) {
            // trying to become a child of the otherItem's parent
            
            if(item.parent != otherItem.parent) {
                
                // can't become a child of the otherItem's parent, if already a child of otherItem
                if(item.parent != otherItem) {
                    if([self nextAvailableItemForOrderingBeforeItem:item] == otherItem) {
                        // become the parent of the otherItem's parent, or nil
                        item.parent = otherItem.parent;
                        updated = YES;
                    }
                }
            }
        }
    }
    
    if(updated) {
        
        // update the stackView arrangedSubviews ordering to reflect the ordering in orderedItems
        [self.stackView sendSubviewToBack:otherItemView];
        [self orderingAnimationWithBlock:^{
            for(NSUInteger i = 0; i < orderedItems.count; i++) {
                
                MenuItem *item = [orderedItems objectAtIndex:i];
                MenuItemView *itemView = [self itemViewForItem:item];
                [self.stackView insertArrangedSubview:itemView atIndex:i];
            }
        }];
        
        self.menu.items = orderedItems;
    }
    
    return updated;
}

- (MenuItem *)nextAvailableItemForOrderingAfterItem:(MenuItem *)item
{
    MenuItem *availableItem = nil;
    NSUInteger itemIndex = [self.menu.items indexOfObject:item];
    
    for(NSUInteger i = itemIndex + 1; itemIndex < self.menu.items.count; i++) {
        
        MenuItem *anItem = [self.menu.items objectAtIndex:i];
        if(![anItem isDescendantOfItem:item]) {
            availableItem = anItem;
            break;
        }
    }
    
    return availableItem;
}

- (MenuItem *)nextAvailableItemForOrderingBeforeItem:(MenuItem *)item
{
    NSUInteger itemIndex = [self.menu.items indexOfObject:item];
    if(itemIndex == 0) {
        return nil;
    }
    
    MenuItem *availableItem = [self.menu.items objectAtIndex:itemIndex - 1];
    return availableItem;
}

- (void)toggleOrderingPlaceHolder:(BOOL)showsPlaceholder forItemViewsWithSelectedItemView:(MenuItemView *)selectedItemView
{
    selectedItemView.isPlaceholder = showsPlaceholder;
    
    if(!selectedItemView.item.children.count) {
        return;
    }
    
    // find any descendant MenuItemViews that should also be set as a placeholder or not
    NSArray *arrangedViews = self.stackView.arrangedSubviews;
    
    NSUInteger itemViewIndex = [arrangedViews indexOfObject:selectedItemView];
    for(NSUInteger i = itemViewIndex + 1; i < arrangedViews.count; i++) {
        UIView *view = [arrangedViews objectAtIndex:i];
        if([view isKindOfClass:[MenuItemView class]]) {
            MenuItemView *itemView = (MenuItemView *)view;
            if([itemView.item isDescendantOfItem:selectedItemView.item]) {
                itemView.isPlaceholder = showsPlaceholder;
            }
        }
    }
}

- (void)orderingAnimationWithBlock:(void(^)())block
{
    [UIView animateWithDuration:0.10 animations:^{
        block();
    } completion:nil];
}

- (void)prepareVisualOrderingViewWithItemView:(MenuItemView *)selectedItemView
{
    MenuItemsVisualOrderingView *orderingView = self.visualOrderingView;
    if(!orderingView) {
        orderingView = [[MenuItemsVisualOrderingView alloc] initWithFrame:self.stackView.bounds];
        orderingView.delegate = self;
        orderingView.translatesAutoresizingMaskIntoConstraints = NO;
        orderingView.backgroundColor = [UIColor clearColor];
        orderingView.userInteractionEnabled = NO;
        orderingView.hidden = YES;
        
        [self addSubview:orderingView];
        [NSLayoutConstraint activateConstraints:@[
                                                  [orderingView.topAnchor constraintEqualToAnchor:self.stackView.topAnchor],
                                                  [orderingView.leadingAnchor constraintEqualToAnchor:self.stackView.leadingAnchor],
                                                  [orderingView.trailingAnchor constraintEqualToAnchor:self.stackView.trailingAnchor],
                                                  [orderingView.bottomAnchor constraintEqualToAnchor:self.stackView.bottomAnchor]
                                                  ]];
        
        self.visualOrderingView = orderingView;
    }
    
    [self.visualOrderingView setupVisualOrderingWithItemView:selectedItemView];
}

- (void)showVisualOrderingView
{
    self.visualOrderingView.hidden = NO;
}

- (void)hideVisualOrderingView
{
    self.visualOrderingView.hidden = YES;
}

#pragma mark - editing

- (void)itemViewWasSelectedForEditing:(MenuItemView *)itemView
{
    if(self.editingView) {
        
        __weak MenuItemsStackView *weakSelf = self;
        MenuItemEditingView *currentEditingView = self.editingView;

        if(currentEditingView.item == itemView.item) {
            
            self.editingView = nil;
            [self hideEditingView:currentEditingView completion:nil];
            
        }else {
            
            self.editingView = [self insertEditingViewForSelectedItemView:itemView];
            [self hideEditingView:currentEditingView completion:^{
                [weakSelf showEditingView:self.editingView];
            }];
        }
        
    }else {
        
        self.editingView = [self insertEditingViewForSelectedItemView:itemView];
        [self showEditingView:self.editingView];
    }
}

- (void)showEditingView:(MenuItemEditingView *)editingView
{
    const CGFloat duration = 0.45;
    [UIView animateWithDuration:duration animations:^{
        
        editingView.hidden = NO;
        editingView.alpha = 1.0;
        
    } completion:^(BOOL finished) {
        
    }];
    
    [UIView animateWithDuration:duration animations:^{
        [self.delegate itemsView:self requiresScrollingToCenterView:editingView];
    }];
}

- (void)hideEditingView:(MenuItemEditingView *)editingView completion:(void(^)())completion
{
    const CGFloat duration = 0.25;
    MenuItemView *itemView = [self itemViewForItem:editingView.item];
    
    [UIView animateWithDuration:duration animations:^{
        
        editingView.hidden = YES;
        editingView.alpha = 0.0;
        
    } completion:^(BOOL finished) {
        
        [self.stackView removeArrangedSubview:editingView];
        [editingView removeFromSuperview];
        
        if(completion) {
            completion();
        }
    }];
    
    [UIView animateWithDuration:duration animations:^{
        [self.delegate itemsView:self requiresScrollingToCenterView:itemView];
    }];
}

- (MenuItemEditingView *)insertEditingViewForSelectedItemView:(MenuItemView *)itemView
{
    NSUInteger viewIndex = [self.stackView.arrangedSubviews indexOfObject:itemView];
    
    MenuItemEditingView *editingView = [[MenuItemEditingView alloc] initWithItem:itemView.item];
    editingView.hidden = YES;
    editingView.alpha = 0.0;

    [self.stackView insertArrangedSubview:editingView atIndex:viewIndex + 1];
    
    [editingView.widthAnchor constraintEqualToAnchor:self.stackView.widthAnchor].active = YES;
    
    NSLayoutConstraint *heightConstraint = [editingView.heightAnchor constraintEqualToConstant:400];
    heightConstraint.priority = UILayoutPriorityDefaultHigh;
    heightConstraint.active = YES;
    
    return editingView;
}

- (void)removeEditingView:(MenuItemEditingView *)editingView completion:(void(^)())completion
{
    [UIView animateWithDuration:0.20 animations:^{
        
        editingView.hidden = YES;
        
    } completion:^(BOOL finished) {
        
        [self.stackView removeArrangedSubview:editingView];
        [editingView removeFromSuperview];
        
        if(completion) {
            completion();
        }
    }];
}

#pragma mark - MenuItemsVisualOrderingViewDelegate

- (void)visualOrderingView:(MenuItemsVisualOrderingView *)visualOrderingView animatingVisualItemViewForOrdering:(MenuItemView *)orderingView
{
    [self.delegate itemsView:self prefersAdjustingScrollingOffsetForAnimatingView:orderingView];
}

#pragma mark - MenuItemViewDelegate

- (void)itemViewSelected:(MenuItemView *)itemView
{
    [self itemViewWasSelectedForEditing:itemView];
}

- (void)itemViewEditingButtonPressed:(MenuItemView *)itemView
{
    [self itemViewWasSelectedForEditing:itemView];
}

- (void)itemViewAddButtonPressed:(MenuItemView *)itemView
{
    [self insertItemInsertionViewsAroundItemView:itemView animated:YES];
}

- (void)itemViewCancelButtonPressed:(MenuItemView *)itemView
{
    [self removeItemInsertionViews:YES];
}

#pragma mark - MenuItemInsertionViewDelegate

- (void)itemInsertionViewSelected:(MenuItemInsertionView *)insertionView
{
    // load the detail view for creating a new item
}

@end