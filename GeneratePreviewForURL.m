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
#import "CSVObject.h"
#import "CSVRowObject.h"

#define MAX_ROWS 200

static char* htmlReadableFileEncoding(NSStringEncoding stringEncoding);
static char* humanReadableFileEncoding(NSStringEncoding stringEncoding);
static char* formatFilesize(float bytes);


/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	NSError *theErr = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSURL *myURL = (NSURL *)url;
	
	// Load document data; guess file encoding using `file --brief --mime` ? Not for now...
	NSStringEncoding stringEncoding;
	NSString *fileString = [NSString stringWithContentsOfURL:myURL usedEncoding:&stringEncoding error:&theErr];
	
	// We could not open the file, probably unknown encoding; try ISO-8859-1
	if(nil == fileString) {
		stringEncoding = NSISOLatin1StringEncoding;
		fileString = [NSString stringWithContentsOfURL:myURL encoding:stringEncoding error:&theErr];
		
		// Still no success, give up
		if(nil == fileString) {
			if(nil != theErr) {
				NSLog(@"Error opening the file: %@", theErr);
			}
			
			[pool release];
			return noErr;
		}
	}
	
	
	// Parse the data if still interested in the preview
	if(false == QLPreviewRequestIsCancelled(preview)) {
		CSVObject *csvObject = [CSVObject csvObject];
		NSUInteger numRowsParsed = [csvObject numRowsFromCSVString:fileString maxRows:MAX_ROWS error:NULL];
		
		
		// Create HTML of the data if still interested in the preview
		if(false == QLPreviewRequestIsCancelled(preview)) {
			NSBundle *myBundle = [NSBundle bundleForClass:[CSVObject class]];
			
			NSString *cssPath = [myBundle pathForResource:@"Style" ofType:@"css"];
			NSString *css = [[NSString alloc] initWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:NULL];
			
			NSString *path = [myURL path];
			NSString *fileName = [[path componentsSeparatedByString:@"/"] lastObject];
			NSDictionary *fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
			
			// compose the html
			NSMutableString *html = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html>\n"];
			[html appendString:@"<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\"><head>\n"];
			[html appendFormat:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=%s\" />\n", htmlReadableFileEncoding(stringEncoding)];
			[html appendString:@"<style>\n"];
			if(nil != css) {
				[html appendString:css];
				[css release];
			}
			[html appendFormat:@"</style></head><body><h1>%@</h1>", fileName];
			[html appendFormat:@"<div class=\"file_info\">%@</div>", path];
			[html appendFormat:@"<div class=\"file_info\">%s, %s</div><table>", formatFilesize([[fileAttributes objectForKey:NSFileSize] floatValue]), humanReadableFileEncoding(stringEncoding)];
			
			// add the table rows
			BOOL altRow = NO;
			for(CSVRowObject *row in csvObject.rows) {
				[html appendFormat:@"<tr%@><td>", altRow ? @" class=\"alt_row\"" : @""];
				[html appendString:[row columns:csvObject.columnKeys separatedByString:@"</td><td>"]];
				[html appendString:@"</td></tr>\n"];
				
				altRow = !altRow;
			}
			
			[html appendString:@"</table>\n"];
			
			// not all rows were parsed, show hint
			if(numRowsParsed > MAX_ROWS) {
				NSString *rowsHint = [NSString stringWithFormat:@"Only the first %i rows are being displayed", MAX_ROWS];
				[html appendFormat:@"<div class=\"truncated_rows\">%@</div>", [myBundle localizedStringForKey:rowsHint value:rowsHint table:nil]];
			}
			[html appendString:@"</html>"];
			
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
	if(NSUTF8StringEncoding == stringEncoding ||
	   NSUnicodeStringEncoding == stringEncoding) {
		return "utf-8";
	}
	if(NSASCIIStringEncoding == stringEncoding) {
		return "ascii";
	}
	if(NSISOLatin1StringEncoding == stringEncoding) {
		return "iso-8859-1";
	}
	if(NSMacOSRomanStringEncoding == stringEncoding) {
		return "x-mac-roman";
	}
	if(NSUTF16BigEndianStringEncoding == stringEncoding ||
	   NSUTF16LittleEndianStringEncoding == stringEncoding) {
		return "utf-16";
	}
	if(NSUTF32StringEncoding == stringEncoding ||
	   NSUTF32BigEndianStringEncoding == stringEncoding ||
	   NSUTF32LittleEndianStringEncoding == stringEncoding) {
		return "utf-32";
	}
	
	return "utf-8";
}


static char* humanReadableFileEncoding(NSStringEncoding stringEncoding)
{
	if(NSUTF8StringEncoding == stringEncoding ||
	   NSUnicodeStringEncoding == stringEncoding) {
		return "UTF-8";
	}
	if(NSASCIIStringEncoding == stringEncoding) {
		return "ASCII-text";
	}
	if(NSISOLatin1StringEncoding == stringEncoding) {
		return "ISO-8859-1";
	}
	if(NSMacOSRomanStringEncoding == stringEncoding) {
		return "Mac-Roman";
	}
	if(NSUTF16BigEndianStringEncoding == stringEncoding ||
	   NSUTF16LittleEndianStringEncoding == stringEncoding) {
		return "UTF-16";
	}
	if(NSUTF32StringEncoding == stringEncoding ||
	   NSUTF32BigEndianStringEncoding == stringEncoding ||
	   NSUTF32LittleEndianStringEncoding == stringEncoding) {
		return "UTF-32";
	}
	
	return "UTF-8";
}


static char* formatFilesize(float bytes) {
	if(bytes < 1) {
		return "";
	}
	
	char *format[] = { "%.0f", "%.0f", "%.2f", "%.2f", "%.2f", "%.2f" };
	char *unit[] = { "Byte", "KB", "MB", "GB", "TB", "PB" };
	int i = 0;
	while(bytes > 1000) {
		bytes /= 1024;
		i++;
	}
	if(i > 5) {		// we won't end up here anyway, but let's be sure
		i = 5;
	}
	
	char formatString[9];
	static char result[10];			// max would be "1023.99 Byte" (12 byte), but that combination should not happen
	sprintf(formatString, "%s %s", format[i], unit[i]);
	sprintf(result, formatString, bytes);
	
	return result;
}


