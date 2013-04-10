
#import "Reporter.h"

#import <sys/stat.h>

#import "Options.h"
#import "PJSONKit.h"
#import "PhabricatorReporter.h"
#import "RawReporter.h"
#import "TextReporter.h"

@implementation Reporter

+ (Reporter *)reporterWithName:(NSString *)name outputPath:(NSString *)outputPath options:(Options *)options
{
  NSDictionary *reporters = @{@"raw": [RawReporter class],
                              @"pretty": [PrettyTextReporter class],
                              @"plain": [PlainTextReporter class],
                              @"phabricator": [PhabricatorReporter class],
                              };
  
  Class reporterClass = reporters[name];

  Reporter *reporter = [[[reporterClass alloc] init] autorelease];
  reporter.outputPath = outputPath;
  reporter.options = options;
  return reporter;
}

- (id)init
{
  if (self = [super init]) {
  }
  return self;
}

- (void)dealloc
{
  [_outputHandle release];
  [_outputPath release];
  [_options release];
  [super dealloc];
}

- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error
{
  if ([self.outputPath isEqualToString:@"-"]) {
    _outputHandle = [standardOutput retain];
    return YES;
  } else {
    if (![[NSFileManager defaultManager] createFileAtPath:self.outputPath contents:nil attributes:nil]) {
      *error = [NSString stringWithFormat:@"Failed to create file at '%@'.", self.outputPath];
      return NO;
    }

    _outputHandle = [[NSFileHandle fileHandleForWritingAtPath:self.outputPath] retain];

    return YES;
  }
}

- (void)handleEvent:(NSDictionary *)eventDict
{
  NSString *event = eventDict[@"event"];
  NSMutableString *selectorName = [NSMutableString string];
  
  int i = 0;
  for (NSString *part in [event componentsSeparatedByString:@"-"]) {
    if (i++ == 0) {
      [selectorName appendString:[part lowercaseString]];
    } else {
      [selectorName appendString:[[part lowercaseString] capitalizedString]];
    }
  }
  [selectorName appendString:@":"];
  
  SEL sel = sel_registerName([selectorName UTF8String]);
  [self performSelector:sel withObject:eventDict];
}

- (void)beginAction:(Action *)action {}
- (void)endAction:(Action *)action succeeded:(BOOL)succeeded {}
- (void)beginBuildTarget:(NSDictionary *)event {}
- (void)endBuildTarget:(NSDictionary *)event {}
- (void)beginBuildCommand:(NSDictionary *)event {}
- (void)endBuildCommand:(NSDictionary *)event {}
- (void)beginXcodebuild:(NSDictionary *)event {}
- (void)endXcodebuild:(NSDictionary *)event {}
- (void)beginOctest:(NSDictionary *)event {}
- (void)endOctest:(NSDictionary *)event {}
- (void)beginTestSuite:(NSDictionary *)event {}
- (void)endTestSuite:(NSDictionary *)event {}
- (void)beginTest:(NSDictionary *)event {}
- (void)endTest:(NSDictionary *)event {}
- (void)testOutput:(NSDictionary *)event {}

- (void)close
{
  // Be sure everything gets flushed.
  struct stat fdstat = {0};
  NSAssert(fstat([_outputHandle fileDescriptor], &fdstat) == 0, @"fstat() failed: %s", strerror(errno));

  // Don't call synchronizeFile for pipes - it's not supported.  All of the automated
  // tests pass around pipes, so it's important to have this check.
  if (!S_ISFIFO(fdstat.st_mode)) {
    [_outputHandle synchronizeFile];
  }
}

@end
