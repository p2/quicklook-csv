//
//  GeneratePreviewForURL.m
//  QuickLookCSV
//
//  Created by Pascal Pfiffner on 03.07.2009.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//  

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "CSVDocument.h"
#import "CSVRowObject.h"

#define MAX_ROWS 500

static char* htmlReadableFileEncoding(NSStringEncoding stringEncoding);
static char* humanReadableFileEncoding(NSStringEncoding stringEncoding);
static char* formatFilesize(float bytes);


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	NSError *theErr = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSURL *myURL = (NSURL *)url;
	
	// Load document data using NSStrings house methods
	// For huge files, maybe guess file encoding using `file --brief --mime` and use NSFileHandle? Not for now...
	NSStringEncoding stringEncoding;
	NSString *fileString = [NSString stringWithContentsOfURL:myURL usedEncoding:&stringEncoding error:&theErr];
	
	// We could not open the file, probably unknown encoding; try ISO-8859-1
	if (nil == fileString) {
		stringEncoding = NSISOLatin1StringEncoding;
		fileString = [NSString stringWithContentsOfURL:myURL encoding:stringEncoding error:&theErr];
		
		// Still no success, give up
		if (nil == fileString) {
			if (nil != theErr) {
				NSLog(@"Error opening the file: %@", theErr);
			}
			
			[pool release];
			return noErr;
		}
	}
	
	
	// Parse the data if still interested in the preview
	if (false == QLPreviewRequestIsCancelled(preview)) {
		CSVDocument *csvDoc = [CSVDocument csvDoc];
		csvDoc.autoDetectSeparator = YES;
		
		NSUInteger numRowsParsed = [csvDoc numRowsFromCSVString:fileString maxRows:MAX_ROWS error:NULL];
		
		// Create HTML of the data if still interested in the preview
		if (false == QLPreviewRequestIsCancelled(preview)) {
			NSBundle *myBundle = [NSBundle bundleForClass:[CSVDocument class]];
			
			NSString *cssPath = [myBundle pathForResource:@"Style" ofType:@"css"];
			NSString *css = [[NSString alloc] initWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:NULL];
			
			NSString *path = [myURL path];
			NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
			
			// compose the html
			NSMutableString *html = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html>\n"];
			[html appendString:@"<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\"><head>\n"];
			[html appendFormat:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=%s\" />\n", htmlReadableFileEncoding(stringEncoding)];
			[html appendString:@"<style>\n"];
			if (nil != css) {
				[html appendString:css];
				[css release];
			}
			
			// info
			NSString *separatorDesc = [@"	" isEqualToString:csvDoc.separator] ? @"Tab" :
										([@"," isEqualToString:csvDoc.separator] ? @"Comma" : 
										 ([@"|" isEqualToString:csvDoc.separator] ? @"Pipe" :
										  ([@";" isEqualToString:csvDoc.separator] ? @"Semicolon" : csvDoc.separator)));
			NSString *numRows = (numRowsParsed > MAX_ROWS) ?
									[NSString stringWithFormat:@"%i+", MAX_ROWS] :
									[NSString stringWithFormat:@"%lu", (unsigned long)numRowsParsed];
			[html appendFormat:@"</style></head><body><div class=\"file_info\"><b>%lu</b> %@, <b>%@</b> %@</div>",
									(unsigned long)[csvDoc.columnKeys count],
									(1 == [csvDoc.columnKeys count]) ? NSLocalizedString(@"column", nil) : NSLocalizedString(@"columns", nil),
									numRows,
									(1 == numRowsParsed) ? NSLocalizedString(@"row", nil) : NSLocalizedString(@"rows", nil)
			];
			[html appendFormat:@"<div class=\"file_info\"><b>%s</b>, %@-%@, %s</div><table>",
									formatFilesize([[fileAttributes objectForKey:NSFileSize] floatValue]),
									NSLocalizedString(separatorDesc, nil),
									NSLocalizedString(@"Separated", nil),
									humanReadableFileEncoding(stringEncoding)
			 ];
			
			// add the table rows
			BOOL altRow = NO;
			for (CSVRowObject *row in csvDoc.rows) {
				[html appendFormat:@"<tr%@><td>", altRow ? @" class=\"alt_row\"" : @""];
				[html appendString:[row columns:csvDoc.columnKeys combinedByString:@"</td><td>"]];
				[html appendString:@"</td></tr>\n"];
				
				altRow = !altRow;
			}
			
			[html appendString:@"</table>\n"];
			
			// not all rows were parsed, show hint
			if (numRowsParsed > MAX_ROWS) {
				NSString *rowsHint = [NSString stringWithFormat:NSLocalizedString(@"Only the first %i rows are being displayed", nil), MAX_ROWS];
				[html appendFormat:@"<div class=\"truncated_rows\">%@</div>", rowsHint];
			}
			[html appendString:@"</html>"];
			
			// feed the HTML
			CFDictionaryRef properties = (CFDictionaryRef)[NSDictionary dictionary];
			QLPreviewRequestSetDataRepresentation(preview,
												  (CFDataRef)[html dataUsingEncoding:stringEncoding],
												  kUTTypeHTML, 
												  properties
												  );
			[html release];
		}
	}
	
	// Clean up
	[pool release];
	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
}


// to be used for the generated HTML
static char* htmlReadableFileEncoding(NSStringEncoding stringEncoding)
{
	if (NSUTF8StringEncoding == stringEncoding ||
	   NSUnicodeStringEncoding == stringEncoding) {
		return "utf-8";
	}
	if (NSASCIIStringEncoding == stringEncoding) {
		return "ascii";
	}
	if (NSISOLatin1StringEncoding == stringEncoding) {
		return "iso-8859-1";
	}
	if (NSMacOSRomanStringEncoding == stringEncoding) {
		return "x-mac-roman";
	}
	if (NSUTF16BigEndianStringEncoding == stringEncoding ||
	   NSUTF16LittleEndianStringEncoding == stringEncoding) {
		return "utf-16";
	}
	if (NSUTF32StringEncoding == stringEncoding ||
	   NSUTF32BigEndianStringEncoding == stringEncoding ||
	   NSUTF32LittleEndianStringEncoding == stringEncoding) {
		return "utf-32";
	}
	
	return "utf-8";
}


static char* humanReadableFileEncoding(NSStringEncoding stringEncoding)
{
	if (NSUTF8StringEncoding == stringEncoding ||
	   NSUnicodeStringEncoding == stringEncoding) {
		return "UTF-8";
	}
	if (NSASCIIStringEncoding == stringEncoding) {
		return "ASCII-text";
	}
	if (NSISOLatin1StringEncoding == stringEncoding) {
		return "ISO-8859-1";
	}
	if (NSMacOSRomanStringEncoding == stringEncoding) {
		return "Mac-Roman";
	}
	if (NSUTF16BigEndianStringEncoding == stringEncoding ||
	   NSUTF16LittleEndianStringEncoding == stringEncoding) {
		return "UTF-16";
	}
	if (NSUTF32StringEncoding == stringEncoding ||
	   NSUTF32BigEndianStringEncoding == stringEncoding ||
	   NSUTF32LittleEndianStringEncoding == stringEncoding) {
		return "UTF-32";
	}
	
	return "UTF-8";
}


static char* formatFilesize(float bytes) {
	if (bytes < 1) {
		return "";
	}
	
	char *format[] = { "%.0f", "%.0f", "%.2f", "%.2f", "%.2f", "%.2f" };
	char *unit[] = { "Byte", "KB", "MB", "GB", "TB", "PB" };
	int i = 0;
	while(bytes > 1000) {
		bytes /= 1024;
		i++;
		
		if (i >= 5) {		// we most likely won't end up here, but let's be sure
			break;
		}
	}
	
	char formatString[10];
	static char result[11];			// max would be "1023.99 Byte" (12 byte), but that combination should not happen
	sprintf(formatString, "%s %s", format[i], unit[i]);
	sprintf(result, formatString, bytes);
	
	return result;
}


