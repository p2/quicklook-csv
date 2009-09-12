#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "CSVDocument.h"
#import "CSVRowObject.h"

#define THUMB_SIZE 256.0
#define ASPECT 0.8			// fraction of width or height
#define NUM_ROWS 14
#define BADGE @"csv"

static CGContextRef createRGBABitmapContext(CGSize pixelSize);
//static CGContextRef createVectorContext(CGSize pixelSize)


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
	
	
	// Parse the data if still interested in the thumbnail
	if (false == QLThumbnailRequestIsCancelled(thumbnail)) {
		CGFloat rowHeight = ceilf(THUMB_SIZE / NUM_ROWS);
		CGFloat fontSize = roundf(0.666 * rowHeight);
		
		CSVDocument *csvDoc = [CSVDocument csvDoc];
		csvDoc.autoDetectSeparator = YES;
		NSUInteger gotRows = [csvDoc numRowsFromCSVString:fileString maxRows:NUM_ROWS error:NULL];
		
		
		// Draw an icon if still interested in the thumbnail
		if ((gotRows > 0) && (false == QLThumbnailRequestIsCancelled(thumbnail))) {
			CGRect maxBounds = CGRectMake(0.0, 0.0, THUMB_SIZE, THUMB_SIZE);
			CGRect usedBounds = CGRectMake(0.0, 0.0, 0.0, 0.0);
			CGFloat badgeMaxSize = THUMB_SIZE;
			
			CGContextRef context = createRGBABitmapContext(maxBounds.size);
			//CGContextRef context = createVectorContext(maxBounds.size);
			if (context) {
				//CGPDFContextBeginPage(context, NULL);
				
				// Flip CoreGraphics coordinate system
				CGContextScaleCTM(context, 1.0, -1.0);
				CGContextTranslateCTM(context, 0, -maxBounds.size.height);		
				
				// Create colors
				CGColorRef borderColor = CGColorCreateGenericRGB(0.67, 0.67, 0.67, 1.0);
				CGColorRef rowBG = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
				CGColorRef altRowBG = CGColorCreateGenericRGB(0.9, 0.9, 0.9, 1.0);
				
				CGFloat borderWidth = 1.0;
				
				// We use NSGraphicsContext for the strings due to easier string drawing :P
				NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)context flipped:YES];
				[NSGraphicsContext setCurrentContext:nsContext];
				if (nil != nsContext) {
					NSFont *myFont = [NSFont systemFontOfSize:fontSize];
					NSColor *rowTextColor = [NSColor colorWithCalibratedWhite:0.25 alpha:1.0];
					NSDictionary *stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:myFont, NSFontAttributeName,
													  rowTextColor, NSForegroundColorAttributeName, nil];
					
					CGFloat textXPadding = 5.0;
					CGFloat cellX = 0.0;
					CGFloat maxCellStringWidth;
					
					// loop each column
					for (NSString *colKey in csvDoc.columnKeys) {
						if (cellX > maxBounds.size.width) {
							break;
						}
						
						CGRect rowRect = CGRectMake(cellX, 0.0, maxBounds.size.width - cellX, rowHeight);
						maxCellStringWidth = 0.0;
						BOOL isFirstColumn = [csvDoc isFirstColumn:colKey];
						BOOL altRow = NO;
						
						// loop rows of this column
						for (CSVRowObject *row in csvDoc.rows) {
							
							// Draw background
							if (isFirstColumn) {
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
							
							if (cellSize.width > maxCellStringWidth) {
								maxCellStringWidth = cellSize.width;
							}
							altRow = !altRow;
							rowRect.origin.y += rowHeight;
							
							// adjust usedBounds
							if (usedBounds.size.height < rowRect.origin.y) {
								usedBounds.size.height = rowRect.origin.y;
							}
						}
						
						cellX += maxCellStringWidth + 2 * textXPadding;
						usedBounds.size.width = cellX;
					}
					
					// adjust the bounds to respect our fixed aspect ratio - portrait
					if (usedBounds.size.width <= usedBounds.size.height) {
						badgeMaxSize = usedBounds.size.height;
						usedBounds.size.width = usedBounds.size.height * ASPECT;
					}
					
					// landscape
					else {
						badgeMaxSize = usedBounds.size.width;
						
						CGFloat my_height = usedBounds.size.width * ASPECT;
						if (usedBounds.size.height < my_height) {
							CGRect missingRect = CGRectMake(0.0, usedBounds.size.height, ceilf(usedBounds.size.width), ceilf(my_height - usedBounds.size.height));
							CGContextSetFillColorWithColor(context, rowBG);
							CGContextFillRect(context, missingRect);
						}
						usedBounds.size.height = my_height;
					}
				}
				
				//CGPDFContextEndPage(context);
				
				CGColorRelease(borderColor);
				CGColorRelease(rowBG);
				CGColorRelease(altRowBG);
				
				// Create a CGImage
				CGImageRef fullImage = CGBitmapContextCreateImage(context);
				CGImageRef usedImage = CGImageCreateWithImageInRect(fullImage, usedBounds);
				CGImageRelease(fullImage);
				
				// Draw the image to the thumbnail request
				CGContextRef thumbContext = QLThumbnailRequestCreateContext(thumbnail, usedBounds.size, false, NULL);
				CGContextDrawImage(thumbContext, usedBounds, usedImage);
				CGImageRelease(usedImage);
				
				// we no longer need the bitmap data; free (malloc'ed by createRGBABitmapContext() )
				char *contextData = CGBitmapContextGetData(context);
				if (contextData) {
					free(contextData);
				}
				
				// Draw the CSV badge to the icon
				NSGraphicsContext *thumbNsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)thumbContext flipped:NO];
				[NSGraphicsContext setCurrentContext:thumbNsContext];
				if (nil != thumbNsContext) {
					NSString *badgeString = BADGE;
					CGFloat badgeFontSize = ceilf(badgeMaxSize * 0.28);
					NSFont *badgeFont = [NSFont boldSystemFontOfSize:badgeFontSize];
					NSColor *badgeColor = [NSColor colorWithCalibratedRed:0.05 green:0.25 blue:0.1 alpha:1.0];
					NSShadow *badgeShadow = [[[NSShadow alloc] init] autorelease];
					[badgeShadow setShadowOffset:NSMakeSize(0.0, 0.0)];
					[badgeShadow setShadowBlurRadius:badgeFontSize * 0.01];
					[badgeShadow setShadowColor:[NSColor whiteColor]];
					
					// Set attributes and draw
					NSDictionary *badgeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:badgeFont, NSFontAttributeName,
																							   badgeColor, NSForegroundColorAttributeName,
																							   badgeShadow, NSShadowAttributeName, nil];
					
					NSSize badgeSize = [badgeString sizeWithAttributes:badgeAttributes];
					CGFloat badge_x = (usedBounds.size.width / 2) - (badgeSize.width / 2);
					CGFloat badge_y = 0.025 * badgeMaxSize;
					NSRect badgeRect = NSMakeRect(badge_x, badge_y, 0.0, 0.0);
					badgeRect.size = badgeSize;
					
					[badgeString drawWithRect:badgeRect options:NSStringDrawingUsesLineFragmentOrigin attributes:badgeAttributes];
				}
				
				
				// Clean up
				QLThumbnailRequestFlushContext(thumbnail, thumbContext);
				CGContextRelease(thumbContext);
				CGContextRelease(context);
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
	if (NULL == bitmapData) {
		fprintf(stderr, "Oops, could not allocate bitmap data!");
		return NULL;
	}
	
	// create the context
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef context = CGBitmapContextCreate(bitmapData, width, height, 8, bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(colorSpace);
	
	// context creation fail
	if (NULL == context) {
		free(bitmapData);
		fprintf(stderr, "Oops, could not create the context!");
		return NULL;
	}
	
	return context;
}

/*
static CGContextRef createVectorContext(CGSize pixelSize)
{
	CGRect mediaBox = CGRectMake(0.0, 0.0, 0.0, 0.0);
	mediaBox.size = pixelSize;
	
	// allocate needed bytes
	CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);		// unlimited size; hopefully we won't regret this :)
	if (NULL == bitmapData) {
		fprintf(stderr, "Oops, could not allocate mutable data!");
		return NULL;
	}
	
	// create the context
	CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(data);
	CGContextRef context = CGPDFContextCreate(consumer, &mediaBox, NULL);	
	CGDataConsumerRelease(consumer);
	
	// context creation fail
	if (NULL == context) {
		free(bitmapData);
		fprintf(stderr, "Oops, could not create the context!");
		return NULL;
	}
	
	return context;
	
	
	// Don't forget creating pages
	// CGPDFContextBeginPage(pdfContext, NULL);
	// CGPDFContextEndPage(pdfContext);
	
	// and release the data
	// CFRelease(data);
}	//	*/

