//
//  SearchViewController.m
//  Created by Keith Harrison on 06-June-2011 http://useyourloaf.com
//  Copyright (c) 2013 Keith Harrison. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//
//  Neither the name of Keith Harrison nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ''AS IS'' AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 

#import "TwitterSearchAppDelegate.h"
#import "SearchViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>

#import "UITableView+ScrollableToBottom.h"

typedef NS_ENUM(NSUInteger, UYLTwitterSearchState)
{
    UYLTwitterSearchStateLoading,
    UYLTwitterSearchStateNotFound,
    UYLTwitterSearchStateRefused,
    UYLTwitterSearchStateFailed
};

@interface SearchViewController ()
{
    TwitterSearchAppDelegate* appDelegate;
    NSString* lastIdStr;

}

@property (nonatomic,strong) NSURLConnection *connection;
@property (nonatomic,strong) NSMutableData *buffer;
@property (nonatomic,strong) NSMutableArray *results;
@property (nonatomic,strong) ACAccountStore *accountStore;
@property (nonatomic,assign) UYLTwitterSearchState searchState;
@property (nonatomic,strong) NSNumber* maxID;
@end


@implementation SearchViewController

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil)
    {
        _accountStore = [[ACAccountStore alloc] init];
    }
    return _accountStore;
}

- (NSString *)searchMessageForState:(UYLTwitterSearchState)state
{
    switch (state)
    {
        case UYLTwitterSearchStateLoading:
            return @"Loading...";
            break;
        case UYLTwitterSearchStateNotFound:
            return @"No results found";
            break;
        case UYLTwitterSearchStateRefused:
            return @"Twitter Access Refused";
            break;
        default:
            return @"Not Available";
            break;
    }
}

- (IBAction)refreshSearchResults
{
    [self cancelConnection];
    [self loadQuery];
}

#pragma mark -
#pragma mark === View Setup ===
#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (TwitterSearchAppDelegate*)[UIApplication sharedApplication].delegate;

    // Add the target action to the refresh control as it seems not to take
    // effect when set in the storyboard.
    _maxID = [NSNumber numberWithUnsignedLongLong:0];
    lastIdStr = nil;
    
    [self.refreshControl addTarget:self action:@selector(refreshSearchResults) forControlEvents:UIControlEventValueChanged];
    
    self.title = self.query;
    [self loadQuery];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self cancelConnection];
}

- (void)dealloc
{
    [self cancelConnection];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark -
#pragma mark === UITableViewDataSource Delegates ===
#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger count = [self.results count];
    return count > 0 ? count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *ResultCellIdentifier = @"ResultCell";
    static NSString *LoadCellIdentifier = @"LoadingCell";
    
    NSUInteger count = [self.results count];
    if ((count == 0) && (indexPath.row == 0))
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LoadCellIdentifier];
        cell.textLabel.text = [self searchMessageForState:self.searchState];
        return cell;
    }
    
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ResultCellIdentifier];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DefaultCell"];
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ResultCellIdentifier];
    
    NSDictionary *tweet = (self.results)[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%zd : %@", indexPath.row, tweet[@"text"]];
    NSString* idStr = tweet[@"id_str"];
/*
    NSNumber* tweetID = [NSNumber numberWithUnsignedLongLong:[idStr longLongValue]]; // 128bit
    if( _maxID > tweetID ){
        _maxID = tweetID;
    }
*/
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ ID:%@",tweet[@"created_at"], idStr];
    
    //NSLog(@"%d:%@ ID:%@",indexPath.row,tweet[@"text"],tweet[@"id"]);
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{   
    if (indexPath.row & 1)
    {
        cell.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    }
    else
    {
        cell.backgroundColor = [UIColor whiteColor];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    //一番下までスクロールしたかどうか
    if(self.tableView.contentOffset.y >= (self.tableView.contentSize.height - self.tableView.bounds.size.height)){
        //まだ表示するコンテンツが存在するか判定し存在するなら○件分を取得して表示更新する
        [self refreshSearchResults];
    }
}

#pragma mark -
#pragma mark === Private methods ===
#pragma mark -

#define RESULTS_PERPAGE @"20"

- (void)loadQuery
{
    NSLog(@"TWEET MAXID:%@",_maxID);
    NSDate* date = [NSDate date];
    [self loadTwitterWithLastId:lastIdStr maxId:nil date:date force:YES]; // ここも非同期になる
    [self.refreshControl endRefreshing];
    [self.tableView flashScrollIndicators];
    return;
    
// 試験中につきここでreturnしとく
    
    self.searchState = UYLTwitterSearchStateLoading;
//    NSString *encodedQuery = [self.query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString* excludeQuery = [NSString stringWithFormat:@"%@ -from:@yu1000maps",self.query];
    NSString* encodedQuery = [excludeQuery stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:^(BOOL granted, NSError *error)
     {
         if (granted)
         {
             NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
             NSNumber* nextID = [NSNumber numberWithUnsignedLongLong:[_maxID unsignedLongLongValue]-1];
             
             NSDictionary *parameters = @{@"count" : RESULTS_PERPAGE,
                                          @"max_id" : nextID,
                                          //@"max_id_str" : [nextID stringValue],
                                          @"result_type" : @"recent",
                                          @"q" : encodedQuery};
             
             SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                     requestMethod:SLRequestMethodGET
                                                               URL:url
                                                        parameters:parameters];
             
             NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
             slRequest.account = [accounts lastObject];             
             NSURLRequest *request = [slRequest preparedURLRequest];
             dispatch_async(dispatch_get_main_queue(), ^{
                 self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
             });
         }
         else
         {
             self.searchState = UYLTwitterSearchStateRefused;
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self.tableView reloadData];
             });
         }
     }];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.buffer = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [self.buffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    
    NSError *jsonParsingError = nil;
    NSDictionary *jsonResults = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
    
    self.results = jsonResults[@"statuses"];
    NSLog(@"%@",self.results);
    if ([self.results count] == 0)
    {
        NSArray *errors = jsonResults[@"errors"];
        if ([errors count])
        {
            self.searchState = UYLTwitterSearchStateFailed;
        }
        else
        {
            self.searchState = UYLTwitterSearchStateNotFound;
        }
    }else{
        NSDictionary* lastTweet = [self.results lastObject];
        NSString* idStr = lastTweet[@"id_str"];

        NSNumber* tweetID = [NSNumber numberWithUnsignedLongLong:[idStr longLongValue]]; // 128bit
//        if( _maxID > tweetID ){
            _maxID = tweetID;
//        }
    }
    
    self.buffer = nil;
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
    [self.tableView flashScrollIndicators];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    self.buffer = nil;
    [self.refreshControl endRefreshing];
    self.searchState = UYLTwitterSearchStateFailed;
    
    [self handleError:error];
    [self.tableView reloadData];
}

- (void)handleError:(NSError *)error
{
    NSString *errorMessage = [error localizedDescription];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error"                              
                                                        message:errorMessage
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)cancelConnection
{
    if (self.connection != nil)
    {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self.connection cancel];
        self.connection = nil;
        self.buffer = nil;
    }    
}

- (void)loadTwitterWithLastId:(NSString *)lastId maxId:(NSString *)maxId date:(NSDate *)date
{
    [self loadTwitterWithLastId:lastId maxId:maxId date:date force:NO];
}

- (void)loadTwitterWithLastId:(NSString *)lastId maxId:(NSString *)maxId date:(NSDate *)date force:(BOOL)force
{
    static int loopStep = 1;
    LOG(@"%d回目のクエリ",loopStep);
    
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:^(BOOL granted, NSError *error){
         if (granted){
             NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
             
             NSString* excludeQuery = [NSString stringWithFormat:@"%@ -from:@yu1000maps",self.query];
             NSString* encodedQuery = [excludeQuery stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

             NSString *urlString = @"https://api.twitter.com/1.1/search/tweets.json"; // タイムライン取得
             
             NSURL *url = [NSURL URLWithString:urlString];
             NSMutableDictionary *params = [NSMutableDictionary dictionary];
             [params setObject:@"100" forKey:@"count"];
             [params setObject:@"recent" forKey:@"result_type"];
             [params setObject:encodedQuery forKey:@"q"];
             
             if (lastId) {
                 [params setObject:lastId forKey:@"since_id"];
             }
             if (maxId) {
                [params setObject:maxId forKey:@"max_id"];
             }

             NSDateFormatter* inputDateFormatter = [appDelegate dateFormatterForService:TMMServiceTwitter];
             
             ACAccountStore *accountStore = [ACAccountStore new];
             ACAccount *account = [accounts lastObject];
             
             SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
             [request setAccount:account];
             [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                 if (error) {
                     // タイムアウトなど、情報取得できなかった場合
                     //LOGSW(@"[VC]loadTwitterWithLastId:error:%d %@", error.code, error.description);
                     //NSDictionary *d = @{@"result":@"error",@"error":error};
                     //[[NSNotificationCenter defaultCenter] postNotificationName:kTwitterLoadComplete object:d];
                     return;
                     
                 }else {
                     // NSData -> JSON Object
                     NSError *jsonParsingError = nil;
                     //NSDictionary *jsonResults = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
                     //id jsonObj = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
                     id jsonObj = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
                     
                     if (![jsonObj isKindOfClass:[NSArray class]]) {
                         // 戻りがエラー
                         //LOGSW(@"[VC]loadTwitterWithLastId:jsonObj != array");
                         // ???: パスワード未入力での通過を確認した
                         if ([jsonObj isKindOfClass:[NSDictionary class]]) {
                             if ([jsonObj objectForKey:@"errors"]) {
                                 NSArray *ary = [jsonObj objectForKey:@"errors"];
                                 //LOGSW(@"ary %@",ary);
                                 if ([[ary objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
                                     NSDictionary *dic = [ary objectAtIndex:0];
                                     if ([dic objectForKey:@"message"]) {
                                         if ([[dic objectForKey:@"message"] isKindOfClass:[NSString class]]) {
                                             //[appDelegate.messageSW localMessageSwitcher_Title:@"Twitter ERROR" Message:[dic objectForKey:@"message"] showLevel:1];
                                             NSLog(@"Twitter ERROR");
                                         }
                                     }
                                 }
                                 
                             }
                         }
                         
                         //self.results = jsonObj[@"statuses"];
                         //NSDictionary *d = @{@"result":@"NotArray"};
                         //[[NSNotificationCenter defaultCenter] postNotificationName:kTwitterLoadComplete object:d];
                         //return;
                         if( self.results == nil ){
                             self.results = [jsonObj[@"statuses"] mutableCopy]; // statusキー内の配列を設定
                             
                         }else{
                             if( jsonObj[@"statuses"] != nil ){
                                 NSMutableArray* newStatus = jsonObj[@"statuses"];
                                 [self.results addObjectsFromArray:newStatus];
                             }
                         }
                         
                         
                     // 配列の場合はそのまま連結
                     }else{
                         //self.results = jsonObj[@"statuses"];
                         if( self.results == nil ){
                             self.results = [jsonObj mutableCopy]; // タイムラインは配列が帰ってくるのでそのまま突っ込む/連結
                         }else{
                             [self.results addObjectsFromArray:jsonObj];
                         }
                     }
                     
                     LOG(@"%zd tweets",[self.results count]);
                     
                     NSDictionary* tweet = [self.results lastObject];
                     _maxID = tweet[@"id"];
                     lastIdStr = [_maxID stringValue];
                     
                     //LOGSW(@"[VC]loadTwitterWithLastId:jsonObj = array");
                     dispatch_async(dispatch_get_main_queue(), ^{
                         [self.tableView reloadData];
                         //[self.tableView scrollToBottomAnimated:YES];
                     });

                 }
             }];
         }else{
             NSLog(@"NO GRANTED");
         }
     }];
    
    
}


@end

