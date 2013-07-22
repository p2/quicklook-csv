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
#define QUOTE_MAGIC_NUM 2

@implementation CSVDocument

@synthesize separator, rows, columnKeys, autoDetectSeparator;


- (id) init
{
	self = [super init];
	if (nil != self) {
		self.separator = @",";
	}
	
	return self;
}

+ (CSVDocument *) csvDoc
{
	return [[[CSVDocument alloc] init] autorelease];
}

- (void) dealloc
{
	self.separator = nil;
	self.rows = nil;
	self.columnKeys = nil;
	
	[super dealloc];
}
#pragma mark -



#pragma mark Parsing from String
- (NSUInteger) numRowsFromCSVString:(NSString *)string error:(NSError **)error
{
	return [self numRowsFromCSVString:string maxRows:0 error:error];
}

- (NSUInteger) numRowsFromCSVString:(NSString *)string maxRows:(NSUInteger)maxRows error:(NSError **)error
{
	NSUInteger numRows = 0;
	NSUInteger quoteCounts = 0;
    
	// String is non-empty
	if ([string length] > 0) {
		NSMutableArray *thisRows = [NSMutableArray array];
		NSMutableArray *thisColumnKeys = [NSMutableArray array];
		
		// Check whether the file uses ";" or TAB as separator by comparing relative occurrences in the first AUTODETECT_NUM_FIRST_CHARS chars
		if (autoDetectSeparator) {
			self.separator = @",";
			
			NSUInteger testStringLength = ([string length] > AUTODETECT_NUM_FIRST_CHARS) ? AUTODETECT_NUM_FIRST_CHARS : [string length];
			NSString *testString = [string substringToIndex:testStringLength];
			NSArray *possSeparators = [NSArray arrayWithObjects:@";", @"	", @"|", nil];
			
			for (NSString *s in possSeparators) {
				if ([[testString componentsSeparatedByString:s] count] > [[testString componentsSeparatedByString:separator] count]) {
					self.separator = s;
				}
			}
		}
		
		// Get newline character set
		NSMutableCharacterSet *newlineCharacterSet = (id)[NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
		[newlineCharacterSet formIntersectionWithCharacterSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];
        
		// Characters where the parser should stop
		NSMutableCharacterSet *importantCharactersSet = (id)[NSMutableCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%@\"", separator]];
		[importantCharactersSet formUnionWithCharacterSet:newlineCharacterSet];
		
		
		// Create scanner and scan the string
		// ideas for the following block from Drew McCormack >> http://www.macresearch.org/cocoa-scientists-part-xxvi-parsing-csv-data
		BOOL insideQuotes = NO;				// needed to determine whether we're inside doublequotes
		BOOL finishedRow = NO;				// used for the inner while loop
		BOOL isNewColumn = NO;
		BOOL skipWhitespace = (NSNotFound == [separator rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location);
		NSMutableDictionary *columns = nil;
		NSMutableString *currentCellString = [NSMutableString string];
		NSUInteger colIndex = 0;
		
		NSScanner *scanner = [NSScanner scannerWithString:string];
		[scanner setCharactersToBeSkipped:nil];
		while(![scanner isAtEnd]) {
			
			// we'll end up here after every row
			insideQuotes = NO;
			finishedRow = NO;
			columns = ([thisColumnKeys count] > 0) ? [NSMutableDictionary dictionaryWithCapacity:[thisColumnKeys count]] : [NSMutableDictionary dictionary];
			[currentCellString setString:@""];
			colIndex = 0;
			
			// Scan row up to the next terminator
			while(!finishedRow) {
				NSString *tempString;
				NSString *colKey;
				if ([thisColumnKeys count] > colIndex) {
					colKey = [thisColumnKeys objectAtIndex:colIndex];
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
				if ([scanner scanString:separator intoString:NULL]) {
					if (insideQuotes) {		// Separator character inside double quotes
						[currentCellString appendString:separator];
					}
					else {					// This is a column separating comma
						[columns setObject:[[currentCellString copy] autorelease] forKey:colKey];
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
                    quoteCounts = 0;
				}
				
				
				// found a doublequote (")
				else if ([scanner scanString:@"\"" intoString:NULL]) {
                    quoteCounts++;
                    
					if ((insideQuotes)  && [scanner scanString:@"\"" intoString:NULL]) { // Replace double - doublequotes with a single doublequote in our string.
						[currentCellString appendString:@"\""]; 
					}
					else {					// Start or end of a quoted string.
                        if (quoteCounts <= QUOTE_MAGIC_NUM)
                            insideQuotes = !insideQuotes;
					}
				}
				
				
				// found a newline
				else if ([scanner scanCharactersFromSet:newlineCharacterSet intoString:&tempString]) {
					if (quoteCounts > QUOTE_MAGIC_NUM)  {		// We're inside quotes - add line break to column text
						[currentCellString appendString:tempString];
					}
					else {					// End of row
						[columns setObject:[[currentCellString copy] autorelease] forKey:colKey];
						if (isNewColumn) {
							[thisColumnKeys addObject:colKey];
						}
						
						finishedRow = YES;
                        quoteCounts = 0;
					}
				}
				
				
				// found the end
				else if ([scanner isAtEnd]) {
					[columns setObject:[[currentCellString copy] autorelease] forKey:colKey];
					if (isNewColumn) {
						[thisColumnKeys addObject:colKey];
					}
					
					finishedRow = YES;
				}
			}
			
			
			// one row scanned - add to the lines array
			if ([columns count] > 0) {
				CSVRowObject *newRow = [CSVRowObject rowFromDict:columns];
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
		NSDictionary *errorDict = [NSDictionary dictionaryWithObject:@"Cannot parse an empty string" forKey:@"userInfo"];
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:errorDict];
	}
	
	return numRows;
}
#pragma mark -



#pragma mark Document Properties
- (BOOL) isFirstColumn:(NSString *)columnKey
{
	if ((nil != columnKeys) && ([columnKeys count] > 0)) {
		return [columnKey isEqualToString:[columnKeys objectAtIndex:0]];
	}
	
	return NO;
}


@end
