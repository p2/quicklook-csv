#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "CSVDocument.h"
#import "CSVRowObject.h"


/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	NSError *theErr = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSURL *myURL = (NSURL *)url;
	
	// Load document data using NSStrings house methods
	// For huge files, maybe guess file encoding using `file --brief --mime` and use NSFileHandle? Not for now...
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
	
	
	// Parse the data if still interested in the thumbnail
	if(false == QLThumbnailRequestIsCancelled(thumbnail)) {
		CGFloat thumbnailSize = 256.0;
		CGFloat fontSize = 12.0;
		CGFloat rowHeight = 18.0;
		NSUInteger numRows = ceilf(thumbnailSize / rowHeight);
		
		CSVDocument *csvDoc = [CSVDocument csvDoc];
		[csvDoc numRowsFromCSVString:fileString maxRows:numRows error:NULL];
		
		
		// Draw an icon if still interested in the thumbnail
		if(false == QLThumbnailRequestIsCancelled(thumbnail)) {
			CGRect myBounds = CGRectMake(0.0, 0.0, thumbnailSize, thumbnailSize);
			CGContextRef context = QLThumbnailRequestCreateContext(thumbnail, myBounds.size, false, NULL);
			
			// Draw a mini table
			if(context) {
				CGContextSaveGState(context);
				
				// Flip CoreGraphics coordinate system
				CGContextScaleCTM(context, 1.0, -1.0);
				CGContextTranslateCTM(context, 0, -myBounds.size.height);		
				
				// Create colors
				CGColorRef borderColor = CGColorCreateGenericRGB(0.67, 0.67, 0.67, 1.0);
				CGColorRef rowBG = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
				CGColorRef altRowBG = CGColorCreateGenericRGB(0.9, 0.9, 0.9, 1.0);
				
				CGFloat borderWidth = 1.0;
				
				// We use NSGraphicsContext for the strings due to easier string drawing :P
				NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)context flipped:YES];
				[NSGraphicsContext setCurrentContext:nsContext];
				if(nsContext) {
					NSFont *myFont = [NSFont systemFontOfSize:fontSize];
					NSColor *blackColor = [NSColor blackColor];
					NSDictionary *stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:myFont, NSFontAttributeName,
													  blackColor, NSForegroundColorAttributeName, nil];
					
					CGFloat textXPadding = 5.0;
					CGFloat cellX = -2 * textXPadding;
					CGFloat maxCellStringWidth = 0.0;
					
					// We loop each cell, row by row for each column
					for(NSString *colKey in csvDoc.columnKeys) {
						cellX += maxCellStringWidth + 2 * textXPadding;
						CGRect rowRect = CGRectMake(cellX, 0.0, myBounds.size.width - cellX, rowHeight);
						maxCellStringWidth = 0.0;
						BOOL altRow = NO;
						
						// loop rows
						for(CSVRowObject *row in csvDoc.rows) {
							CGContextSetFillColorWithColor(context, altRow ? altRowBG : rowBG);
							CGContextFillRect(context, rowRect);
							
							if(![csvDoc isFirstColumn:colKey]) {
								CGContextMoveToPoint(context, cellX + borderWidth / 2, rowRect.origin.y);
								CGContextAddLineToPoint(context, cellX + borderWidth / 2, rowRect.origin.y + rowRect.size.height);
								CGContextSetStrokeColorWithColor(context, borderColor);
								CGContextStrokePath(context);
							}
							
							// Draw text
							NSRect textRect = NSRectFromCGRect(rowRect);
							textRect.size.width -= 2 * textXPadding;
							textRect.origin.x += textXPadding;
							NSString *cellString = [row columnForKey:colKey];
							NSSize cellSize = [cellString sizeWithAttributes:stringAttributes];
							[cellString drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin attributes:stringAttributes];
							
							if(cellSize.width > maxCellStringWidth) {
								maxCellStringWidth = cellSize.width;
							}
							altRow = !altRow;
							rowRect.origin.y += rowHeight;
						}
					}
				}
				
				CGColorRelease(borderColor);
				CGColorRelease(rowBG);
				CGColorRelease(altRowBG);
				
				// Clean up
				CGContextRestoreGState(context);
				QLThumbnailRequestFlushContext(thumbnail, context);
				CFRelease(context);
			}
		}
	}
	
	// Clean up
	[pool release];
	return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
}

