//
//  CSVDocument.h
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.09.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#import <Cocoa/Cocoa.h>


@interface CSVDocument : NSObject {
	NSString *separator;
	NSArray *rows;
	NSArray *columnKeys;
}

@property (nonatomic, retain) NSString *separator;
@property (nonatomic, retain) NSArray *rows;
@property (nonatomic, retain) NSArray *columnKeys;

+ (CSVDocument *) csvDoc;
- (NSUInteger) numRowsFromCSVString:(NSString *)string error:(NSError **)error;
- (NSUInteger) numRowsFromCSVString:(NSString *)string maxRows:(NSUInteger)maxRows error:(NSError **)error;

- (BOOL) isFirstColumn:(NSString *)columnKey;


@end
