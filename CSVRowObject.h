//
//  CSVRowObject.h
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.09.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#import <Cocoa/Cocoa.h>


@interface CSVRowObject : NSObject {
	NSDictionary *columns;
}

@property (nonatomic, retain) NSDictionary *columns;

+ (CSVRowObject *) row;
+ (CSVRowObject *) rowFromDict:(NSMutableDictionary *)dict;

- (NSString *) columns:(NSArray *)columnKeys combinedByString:(NSString *)sepString;
- (NSString *) columnForKey:(NSString *)columnKey;

@end
