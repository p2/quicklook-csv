//
//  CSVRowObject.m
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.09.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#import "CSVRowObject.h"


@implementation CSVRowObject


/**
 *  Instantiates an object with the given row-dictionary.
 */
+ (CSVRowObject *)newWithDictionary:(NSMutableDictionary *)dict
{
	CSVRowObject *row = [CSVRowObject new];
	
	if (dict) {
		row.columns = dict;
	}
	
	return row;
}



#pragma mark Returning Columns
- (NSString *)columns:(NSArray *)columnKeys combinedByString:(NSString *)sepString
{
	NSString *rowString = nil;
	
	if ((nil != columnKeys) && (nil != _columns)) {
		rowString = [[_columns objectsForKeys:columnKeys notFoundMarker:@""] componentsJoinedByString:sepString];
	}
	
	return rowString;
}

- (NSString *)columnForKey:(NSString *)columnKey
{
	NSString *cellString = nil;
	
	if ((nil != columnKey) && (nil != _columns)) {
		cellString = _columns[columnKey];
	}
	
	return cellString;
}


@end
