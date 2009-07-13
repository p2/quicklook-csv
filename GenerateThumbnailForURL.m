#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "CSVDocument.h"
#import "CSVRowObject.h"

#define MIN_WIDTH 40.0

static CGContextRef createRGBABitmapContext(CGSize pixelSize);


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
		NSUInteger gotRows = [csvDoc numRowsFromCSVString:fileString maxRows:numRows error:NULL];
		
		
		// Draw an icon if still interested in the thumbnail
		if((gotRows > 0) && (false == QLThumbnailRequestIsCancelled(thumbnail))) {
			CGRect maxBounds = CGRectMake(0.0, 0.0, thumbnailSize, thumbnailSize);
			CGRect usedBounds = CGRectMake(0.0, 0.0, thumbnailSize, thumbnailSize);
			
			CGContextRef context = createRGBABitmapContext(maxBounds.size);
			if(context) {
				
				// Flip CoreGraphics coordinate system
				CGContextScaleCTM(context, 1.0, -1.0);
				CGContextTranslateCTM(context, 0, -maxBounds.size.height);		
				
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
					CGFloat cellX = 0.0;
					CGFloat maxCellStringWidth = 0.0;
					
					// We loop each cell, row by row for each column
					for(NSString *colKey in csvDoc.columnKeys) {
						if(cellX > maxBounds.size.width) {
							break;
						}
						
						CGRect rowRect = CGRectMake(cellX, 0.0, maxBounds.size.width - cellX, rowHeight);
						maxCellStringWidth = 0.0;
						BOOL altRow = NO;
						BOOL isFirstColumn = [csvDoc isFirstColumn:colKey];
						
						// loop rows
						for(CSVRowObject *row in csvDoc.rows) {
							
							// Draw background
							if(isFirstColumn) {
								CGContextSetFillColorWithColor(context, altRow ? altRowBG : rowBG);
								CGContextFillRect(context, rowRect);
							}
							
							// Draw border
							else {
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
						
						cellX += maxCellStringWidth + 2 * textXPadding;
					}
					
					// adjust usedBounds.size.width...
					if(cellX < maxBounds.size.width) {
						usedBounds.size.width = (cellX < MIN_WIDTH) ? MIN_WIDTH : cellX;
					}
					
					// ...and usedBounds.size.height
					if(gotRows < numRows) {
						usedBounds.size.height = gotRows * rowHeight;
					}
				}
				
				CGColorRelease(borderColor);
				CGColorRelease(rowBG);
				CGColorRelease(altRowBG);
				
				// Draw the image to the thumbnail request
				CGContextRef thumbContext = QLThumbnailRequestCreateContext(thumbnail, usedBounds.size, false, NULL);
				
				CGImageRef fullImage = CGBitmapContextCreateImage(context);
				CGImageRef usedImage = CGImageCreateWithImageInRect(fullImage, usedBounds);
				CGImageRelease(fullImage);
				CGContextDrawImage(thumbContext, usedBounds, usedImage);
				CGImageRelease(usedImage);
				
				// we no longer need the bitmap data; free
				char *bitmapData = CGBitmapContextGetData(context);
				if(bitmapData) {
					free(bitmapData);
				}
				CFRelease(context);
				
				QLThumbnailRequestFlushContext(thumbnail, thumbContext);
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
#pragma mark -



#pragma mark Creating a bitmap context
static CGContextRef createRGBABitmapContext(CGSize pixelSize)
{
	NSUInteger width = pixelSize.width;
	NSUInteger height = pixelSize.height;
	NSUInteger bitmapBytesPerRow = width * 4;				// 1 byte per component r g b a
	NSUInteger bitmapBytes = bitmapBytesPerRow * height;
	
	// allocate needed bytes
	void *bitmapData = malloc(bitmapBytes);
	if(NULL == bitmapData) {
		fprintf(stderr, "Oops, could not allocate bitmap data!");
		return NULL;
	}
	
	// create the context
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef context = CGBitmapContextCreate(bitmapData, width, height, 8, bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(colorSpace);
	
	// context creation fail
	if(NULL == context) {
		free(bitmapData);
		fprintf(stderr, "Oops, could not create the context!");
		return NULL;
	}
	
	return context;
}

