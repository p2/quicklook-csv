//
//  CSVDocument.h
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.09.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#import <Cocoa/Cocoa.h>


/**
 *  An object representing data in a CSV file.
 */
@interface CSVDocument : NSObject

@property (copy, nonatomic) NSString *separator;
@property (copy, nonatomic) NSArray *rows;
@property (copy, nonatomic) NSArray *columnKeys;

@property (nonatomic, assign) BOOL autoDetectSeparator;

- (NSUInteger)numRowsFromCSVString:(NSString *)string error:(NSError **)error;
- (NSUInteger)numRowsFromCSVString:(NSString *)string maxRows:(NSUInteger)maxRows error:(NSError **)error;

- (BOOL)isFirstColumn:(NSString *)columnKey;

@end
