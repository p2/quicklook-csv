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

@synthesize columns;

+ (CSVRowObject *) row
{
	CSVRowObject *row = [[[CSVRowObject alloc] init] autorelease];
	return row;
}


+ (CSVRowObject *) rowFromDict:(NSMutableDictionary *)dict
{
	CSVRowObject *row = [CSVRowObject row];
	
	if(dict) {
		row.columns = dict;
	}
	
	return row;
}

- (void) dealloc
{
	self.columns = nil;
	
	[super dealloc];
}
#pragma mark -



#pragma mark Returning Columns
- (NSString *) columns:(NSArray *)columnKeys combinedByString:(NSString *)sepString
{
	NSString *rowString = nil;
	
	if((nil != columnKeys) && (nil != columns)) {
		rowString = [[columns objectsForKeys:columnKeys notFoundMarker:@""] componentsJoinedByString:sepString];
	}
	
	return rowString;
}

- (NSString *) columnForKey:(NSString *)columnKey
{
	NSString *cellString = nil;
	
	if((nil != columnKey) && (nil != columns)) {
		cellString = [columns objectForKey:columnKey];
	}
	
	return cellString;
}


@end
