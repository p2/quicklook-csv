#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "CSVDocument.h"
#import "CSVRowObject.h"

#define THUMB_SIZE 512.0
#define ASPECT 0.8			// aspect ratio
#define NUM_ROWS 18
#define BADGE_CSV @"csv"
#define BADGE_TSV @"tab"

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
		CGFloat fontSize = roundf(0.666f * rowHeight);
		
		CSVDocument *csvDoc = [CSVDocument csvDoc];
		csvDoc.autoDetectSeparator = YES;
		NSUInteger gotRows = [csvDoc numRowsFromCSVString:fileString maxRows:NUM_ROWS error:NULL];
		
		
		// Draw an icon if still interested in the thumbnail
		if ((gotRows > 0) && (false == QLThumbnailRequestIsCancelled(thumbnail))) {
			CGRect maxBounds = CGRectMake(0.f, 0.f, THUMB_SIZE, THUMB_SIZE);
			CGRect usedBounds = CGRectMake(0.f, 0.f, 0.f, 0.f);
			CGFloat badgeMaxSize = THUMB_SIZE;
			
			CGContextRef context = createRGBABitmapContext(maxBounds.size);
			//CGContextRef context = createVectorContext(maxBounds.size);
			if (context) {
				//CGPDFContextBeginPage(context, NULL);
				
				// Flip CoreGraphics coordinate system
				CGContextScaleCTM(context, 1.f, -1.f);
				CGContextTranslateCTM(context, 0, -maxBounds.size.height);		
				
				// Create colors
				CGColorRef borderColor = CGColorCreateGenericRGB(0.67f, 0.67f, 0.67f, 1.f);
				CGColorRef rowBG = CGColorCreateGenericRGB(1.f, 1.f, 1.f, 1.f);
				CGColorRef altRowBG = CGColorCreateGenericRGB(0.9f, 0.9f, 0.9f, 1.f);
				
				CGFloat borderWidth = 1.f;
				
				// We use NSGraphicsContext for the strings due to easier string drawing :P
				NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)context flipped:YES];
				[NSGraphicsContext setCurrentContext:nsContext];
				if (nil != nsContext) {
					NSFont *myFont = [NSFont systemFontOfSize:fontSize];
					NSColor *rowTextColor = [NSColor colorWithCalibratedWhite:0.25f alpha:1.f];
					NSDictionary *stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:myFont, NSFontAttributeName,
													  rowTextColor, NSForegroundColorAttributeName, nil];
					
					CGFloat textXPadding = 5.f;
					CGFloat cellX = 0.f;
					CGFloat maxCellStringWidth;
					
					// loop each column
					for (NSString *colKey in csvDoc.columnKeys) {
						if (cellX > maxBounds.size.width) {
							break;
						}
						
						CGRect rowRect = CGRectMake(cellX, 0.f, maxBounds.size.width - cellX, rowHeight);
						maxCellStringWidth = 0.f;
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
					if ((usedBounds.size.width > maxBounds.size.width && usedBounds.size.height > maxBounds.size.height) ||
						(usedBounds.size.width <= usedBounds.size.height)) {
						badgeMaxSize = usedBounds.size.height;
						usedBounds.size.width = usedBounds.size.height * ASPECT;
					}
					
					// landscape
					else {
						badgeMaxSize = usedBounds.size.width;
						
						CGFloat my_height = usedBounds.size.width * ASPECT;
						if (usedBounds.size.height < my_height) {
							CGRect missingRect = CGRectMake(0.f, usedBounds.size.height, ceilf(usedBounds.size.width), ceilf(my_height - usedBounds.size.height));
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
					NSString *badgeString = [@"	" isEqualToString:csvDoc.separator] ? BADGE_TSV : BADGE_CSV;
					CGFloat badgeFontSize = ceilf(badgeMaxSize * 0.28f);
					NSFont *badgeFont = [NSFont boldSystemFontOfSize:badgeFontSize];
					NSColor *badgeColor = [NSColor colorWithCalibratedRed:0.05f green:0.25f blue:0.1f alpha:1.f];
					NSShadow *badgeShadow = [[[NSShadow alloc] init] autorelease];
					[badgeShadow setShadowOffset:NSMakeSize(0.f, 0.f)];
					[badgeShadow setShadowBlurRadius:badgeFontSize * 0.01f];
					[badgeShadow setShadowColor:[NSColor whiteColor]];
					
					// Set attributes and draw
					NSDictionary *badgeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:badgeFont, NSFontAttributeName,
																							   badgeColor, NSForegroundColorAttributeName,
																							   badgeShadow, NSShadowAttributeName, nil];
					
					NSSize badgeSize = [badgeString sizeWithAttributes:badgeAttributes];
					CGFloat badge_x = (usedBounds.size.width / 2) - (badgeSize.width / 2);
					CGFloat badge_y = 0.025f * badgeMaxSize;
					NSRect badgeRect = NSMakeRect(badge_x, badge_y, 0.f, 0.f);
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
	CGRect mediaBox = CGRectMake(0.f, 0.f, 0.f, 0.f);
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

