//
//  CSVDocument.m
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.09.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#import "CSVDocument.h"
#import "CSVRowObject.h"

#define AUTODETECT_NUM_FIRST_CHARS 1000


@implementation CSVDocument


- (id)init
{
	if ((self = [super init])) {
		self.separator = @",";
	}
	
	return self;
}



#pragma mark Parsing from String
/**
 *  Parse the given string into CSV rows.
 */
- (NSUInteger)numRowsFromCSVString:(NSString *)string error:(NSError **)error
{
	return [self numRowsFromCSVString:string maxRows:0 error:error];
}

/**
 *  Parse the given string into CSV rows, up to a given number of rows if "maxRows" is greater than 0.
 */
- (NSUInteger)numRowsFromCSVString:(NSString *)string maxRows:(NSUInteger)maxRows error:(NSError **)error
{
	NSUInteger numRows = 0;
	
	// String is non-empty
	if ([string length] > 0) {
		NSMutableArray *thisRows = [NSMutableArray array];
		NSMutableArray *thisColumnKeys = [NSMutableArray array];
		
		// Check whether the file uses ";" or TAB as separator by comparing relative occurrences in the first AUTODETECT_NUM_FIRST_CHARS chars
		if (_autoDetectSeparator) {
			self.separator = @",";
			
			NSUInteger testStringLength = ([string length] > AUTODETECT_NUM_FIRST_CHARS) ? AUTODETECT_NUM_FIRST_CHARS : [string length];
			NSString *testString = [string substringToIndex:testStringLength];
			NSArray *possSeparators = @[@";", @"	", @"|"];
			
			for (NSString *s in possSeparators) {
				if ([[testString componentsSeparatedByString:s] count] > [[testString componentsSeparatedByString:_separator] count]) {
					self.separator = s;
				}
			}
		}
		
		// Get newline character set
		NSMutableCharacterSet *newlineCharacterSet = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
		[newlineCharacterSet formIntersectionWithCharacterSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];
		
		// Characters where the parser should stop
		NSMutableCharacterSet *importantCharactersSet = [NSMutableCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%@\"", _separator]];
		[importantCharactersSet formUnionWithCharacterSet:newlineCharacterSet];
		
		
		// Create scanner and scan the string
		// ideas for the following block from Drew McCormack >> http://www.macresearch.org/cocoa-scientists-part-xxvi-parsing-csv-data
		BOOL insideQuotes = NO;				// needed to determine whether we're inside doublequotes
		BOOL finishedRow = NO;				// used for the inner while loop
		BOOL isNewColumn = NO;
		BOOL skipWhitespace = (NSNotFound == [_separator rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location);
		NSMutableDictionary *columns = nil;
		NSMutableString *currentCellString = [NSMutableString string];
		NSUInteger colIndex = 0;
		
		NSScanner *scanner = [NSScanner scannerWithString:string];
		[scanner setCharactersToBeSkipped:nil];
		while (![scanner isAtEnd]) {
			
			// we'll end up here after every row
			insideQuotes = NO;
			finishedRow = NO;
			columns = ([thisColumnKeys count] > 0) ? [NSMutableDictionary dictionaryWithCapacity:[thisColumnKeys count]] : [NSMutableDictionary dictionary];
			[currentCellString setString:@""];
			colIndex = 0;
			
			// Scan row up to the next terminator
			while (!finishedRow) {
				NSString *tempString;
				NSString *colKey;
				if ([thisColumnKeys count] > colIndex) {
					colKey = thisColumnKeys[colIndex];
					isNewColumn = NO;
				}
				else {
					colKey = [NSString stringWithFormat:@"col_%lu", (unsigned long)colIndex];
					isNewColumn = YES;
				}
				
				
				// Scan characters into our string
				if ([scanner scanUpToCharactersFromSet:importantCharactersSet intoString:&tempString] ) {
					[currentCellString appendString:tempString];
				}
				
				
				// found the separator
				if ([scanner scanString:_separator intoString:NULL]) {
					if (insideQuotes) {		// Separator character inside double quotes
						[currentCellString appendString:_separator];
					}
					else {					// This is a column separating comma
						columns[colKey] = [currentCellString copy];
						if (isNewColumn) {
							[thisColumnKeys addObject:colKey];
						}
						
						// on to the next column/cell!
						[currentCellString setString:@""];
						if (skipWhitespace) {
							[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
						}
						colIndex++;
					}
				}
				
				
				// found a doublequote (")
				else if ([scanner scanString:@"\"" intoString:NULL]) {
					if (insideQuotes && [scanner scanString:@"\"" intoString:NULL]) { // Replace double - doublequotes with a single doublequote in our string.
						[currentCellString appendString:@"\""]; 
					}
					else {					// Start or end of a quoted string.
						insideQuotes = !insideQuotes;
					}
				}
				
				
				// found a newline
				else if ([scanner scanCharactersFromSet:newlineCharacterSet intoString:&tempString]) {
					if (insideQuotes) {		// We're inside quotes - add line break to column text
						[currentCellString appendString:tempString];
					}
					else {					// End of row
						columns[colKey] = [currentCellString copy];
						if (isNewColumn) {
							[thisColumnKeys addObject:colKey];
						}
						
						finishedRow = YES;
					}
				}
				
				
				// found the end
				else if ([scanner isAtEnd]) {
					columns[colKey] = [currentCellString copy];
					if (isNewColumn) {
						[thisColumnKeys addObject:colKey];
					}
					
					finishedRow = YES;
				}
			}
			
			
			// one row scanned - add to the lines array
			if ([columns count] > 0) {
				CSVRowObject *newRow = [CSVRowObject newWithDictionary:columns];
				[thisRows addObject:newRow];
			}
			
			numRows++;
			if ((maxRows > 0) && (numRows > maxRows)) {
				break;
			}
		}
		
		// finished scanning our string
		self.rows = thisRows;
		self.columnKeys = thisColumnKeys;
	}
	
	// empty string
	else if (nil != error) {
		NSDictionary *errorDict = @{@"userInfo": @"Cannot parse an empty string"};
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:errorDict];
	}
	
	return numRows;
}



#pragma mark - Document Properties
- (BOOL)isFirstColumn:(NSString *)columnKey
{
	if ((nil != _columnKeys) && ([_columnKeys count] > 0)) {
		return [columnKey isEqualToString:_columnKeys[0]];
	}
	
	return NO;
}


@end
