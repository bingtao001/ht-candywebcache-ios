//
//  HTThreadSafeMutableDictionary.m
//  Pods
//
//  Created by 小丸子 on 20/7/2016.
//
//

#import "HTThreadSafeMutableDictionary.h"

#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

#define LOCKED(...) do { \
OSSpinLockLock(&_lock); \
__VA_ARGS__; \
OSSpinLockUnlock(&_lock); \
} while (NO)

@interface HTThreadSafeMutableDictionary()
@property (nonatomic, assign) OSSpinLock lock;
@property (nonatomic, copy) NSMutableDictionary* dictionary;
@end

@implementation HTThreadSafeMutableDictionary {
    
    
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        _dictionary = [[NSMutableDictionary alloc] init];
        _lock = OS_SPINLOCK_INIT;
    }
    return self;
}

- (id)initWithObjects:(NSArray *)objects forKeys:(NSArray *)keys {
    if ((self = [self initWithCapacity:objects.count])) {
        [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            _dictionary[keys[idx]] = obj;
        }];
    }
    return self;
}

- (id)initWithCapacity:(NSUInteger)capacity {
    if ((self = [super init])) {
        _dictionary = [[NSMutableDictionary alloc] initWithCapacity:capacity];
        _lock = OS_SPINLOCK_INIT;
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSMutableDictionary

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    LOCKED(_dictionary[aKey] = anObject);
}

- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary {
    LOCKED([_dictionary addEntriesFromDictionary:otherDictionary]);
}

- (void)setDictionary:(NSDictionary *)otherDictionary {
    LOCKED([_dictionary setDictionary:otherDictionary]);
}

- (void)removeObjectForKey:(id)aKey {
    LOCKED([_dictionary removeObjectForKey:aKey]);
}

- (void)removeAllObjects {
    LOCKED([_dictionary removeAllObjects]);
}

- (NSUInteger)count {
    NSUInteger count;
    LOCKED(count = _dictionary.count);
    return count;
}

- (NSArray *)allKeys {
    NSArray *allKeys;
    LOCKED(allKeys = _dictionary.allKeys);
    return allKeys;
}

- (NSArray *)allValues {
    NSArray *allValues;
    LOCKED(allValues = _dictionary.allValues);
    return allValues;
}

- (id)objectForKey:(id)aKey {
    id obj;
    LOCKED(obj = _dictionary[aKey]);
    return obj;
}

- (NSEnumerator *)keyEnumerator {
    NSEnumerator *keyEnumerator;
    LOCKED(keyEnumerator = [_dictionary keyEnumerator]);
    return keyEnumerator;
}

- (id)copyWithZone:(NSZone *)zone {
    return [self mutableCopyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    id copiedDictionary;
    LOCKED(copiedDictionary = [[self.class allocWithZone:zone] initWithDictionary:_dictionary]);
    return copiedDictionary;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])stackbuf
                                    count:(NSUInteger)len {
    OSSpinLockLock(&_lock);
    
    NSDictionary *enumerationDict = objc_getAssociatedObject(self, &stackbuf);
    if (!enumerationDict) {
        objc_setAssociatedObject(self, &stackbuf, (enumerationDict = _dictionary.copy), OBJC_ASSOCIATION_RETAIN);
    }
    
    NSUInteger count = [enumerationDict countByEnumeratingWithState:state objects:stackbuf count:len];
    
    if (!count) {
        objc_setAssociatedObject(self, &stackbuf, nil, OBJC_ASSOCIATION_RETAIN);
    }
    
    OSSpinLockUnlock(&_lock);
    
    return count;
}

- (void)performLockedWithDictionary:(void (^)(NSDictionary *dictionary))block {
    if (block)
        LOCKED(block(_dictionary));
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    
    if ([object isKindOfClass:HTThreadSafeMutableDictionary.class]) {
        HTThreadSafeMutableDictionary *other = object;
        __block BOOL isEqual = NO;
        [other performLockedWithDictionary:^(NSDictionary *dictionary) {
            [self performLockedWithDictionary:^(NSDictionary *otherDictionary) {
                isEqual = [dictionary isEqual:otherDictionary];
            }];
        }];
        return isEqual;
    }
    return NO;
}

- (NSUInteger)hash
{
    NSUInteger hash;
    LOCKED(hash = [super hash]);
    return hash;
}

@end
