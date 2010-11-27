/*
 * MixpanelAPI.j
 *
 * Created by Fred Potter on November 21, 2010.
 * 
 * The MIT License
 * 
 * Copyright (c) 2010 Fred Potter
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */

@import <Foundation/Foundation.j>

var SharedMixpanelAPIInstance = nil;

MPLibEventTypeEvent = 1;
MPLibEventTypeFunnel = 2,
MPLibEventTypeAll = 3

@implementation MixpanelAPI : CPObject
{
    CPString _apiToken;
    
    var _mpmetrics;
    CPArray _queue;
}

+ (MixpanelAPI)sharedAPIWithToken:(CPString)apiToken
{
    if (SharedMixpanelAPIInstance != nil)
    {
        [CPException raise:CPInternalInconsistencyException
                    reason:"Mixpanel can only be initialized once."];
    }
    else
    {
        SharedMixpanelAPIInstance = [[MixpanelAPI alloc] initWithApiToken:apiToken];
        return SharedMixpanelAPIInstance;
    }
}

+ (MixpanelAPI)sharedAPI
{
    if (SharedMixpanelAPIInstance != nil)
    {
        return SharedMixpanelAPIInstance;
    }
    else
    {
        [CPException raise:CPInternalInconsistencyException
                    reason:"Mixpanel must first be initialized with sharedAPIWithToken:"];
    }
}

- (id)initWithApiToken:(CPString)apiToken
{
    if (self = [super init])
    {
        _apiToken = apiToken;
        _queue = [];
        
        var script = document.createElement("script");
        script.src = (('https:' == document.location.protocol) ? 'https://' : 'http://') + 'api.mixpanel.com/site_media/js/api/mixpanel.js';
        script.type = "text/javascript";
        script.charset = "UTF-8";    

        // Either one or the other of the following handlers will get
        // called, depending on the browser.
        script.onreadystatechange = function () {
            if (this.readyState == 'complete')
            {
                [self onScriptLoaded];
            }
        };

        script.onload = function()
        {
            [self onScriptLoaded];
        };

        document.getElementsByTagName("head")[0].appendChild(script);
    }
    return self;
}

- (void)onScriptLoaded
{
    try
    {
        _mpmetrics = new MixpanelLib(_apiToken);
        CPLog.info("Mixpanel loaded.");
    }
    catch(err)
    {
        CPLog.warn("Mixpanel failed to load: " + err);
        var null_fn = function () {};
        _mpmetrics =
        {
            track: null_fn,
            track_funnel: null_fn,
            register: null_fn,
            register_once: null_fn,
            register_funnel: null_fn
        };
    }
    
    window.mpmetrics = _mpmetrics;
    
    // If any work got queued up while we were waiting for the script to load...
    for (var i = 0, count = [_queue count]; i < count; i++)
    {
        var func = _queue[i];
        func();
    }
    
    [_queue removeAllObjects];
}

- (void)enqueueOrDo:(JSFunction)func
{
    if (_mpmetrics != nil)
    {
        func();
    }
    else
    {
        // Script isn't loaded yet - we'll get it later
        [_queue addObject:func];
    }
}

- (JSObject)JSObjectFromDictionary:(CPDictionary)dict
{
    var obj = {};
    
    [dict allKeys].forEach(function(key)
    {
        obj[key] = [dict objectForKey:key];
    });
    
    return obj;
}

/*!
    @method         registerSuperProperties:
    @abstract       Registers a set of super properties for all event types.
    @discussion     Registers a set of super properties, overwriting property values if they already exist. 
                    Super properties are added to all the data points.                 
                    The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.  
    @param          properties a NSDictionary with the super properties to register.
                    properties that will be registered with both events and funnels.
 
 */
- (void)registerSuperProperties:(CPDictionary)properties
{
    [self registerSuperProperties:properties eventType:MPLibEventTypeAll];
}

- (void)registerSuperProperties:(CPDictionary)properties eventType:(int)eventType
{
    [self registerSuperProperties:properties eventType:eventType days:7];
}

/*!
    @method     registerSuperProperties:eventType:
    @abstract   Registers a set of super properties for a specified event type.
    @discussion Registers a set of super properties, overwriting property values if they already exist. 
                Super properties are added to all the data points of the specified event type.              
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.   
    @param      properties a NSDictionary with the super properties to register.
    @param      eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
                properties that will be registered with both events and funnels.
    @param      days Age of cookie in days. The cookie is set frequently so this has little effect.
                Default 7
    
 */
- (void)registerSuperProperties:(CPDictionary)properties eventType:(int)eventType days:(int)days
{
    var eventTypeString = nil;
    
    if (eventType == MPLibEventTypeEvent)
    {
        eventTypeString = "events";
    }
    else if (eventType == MPLibEventTypeFunnel)
    {
        eventTypeString = "funnels";
    }
    else if (eventType == MPLibEventTypeAll)
    {
        eventTypeString = "all";
    }
    else
    {
        [CPException raise:CPInvalidArgumentException reason:"Invalid event type: " + eventType];
    }
    
    [self enqueueOrDo:function()
    {
        _mpmetrics.register([self JSObjectFromDictionary:properties], eventTypeString, days);
    }];
}


/*!
    @method     registerSuperPropertiesOnce:
    @abstract   Registers a set of super properties unless the property already exists.
    @discussion Registers a set of super properties, without overwriting existing key\value pairs. 
                Super properties are added to all the data points.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      properties a NSDictionary with the super properties to register.
                properties that will be registered with both events and funnels.
 */
- (void)registerSuperPropertiesOnce:(CPDictionary)properties
{
    
}

/*!
    @method     registerSuperPropertiesOnce:eventType:
    @abstract   Registers a set of super properties for a specified event type unless the property already exists.
    @discussion Registers a set of super properties, without overwriting existing key\value pairs. 
                Super properties are added to all the data points of the specified event type.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      properties a NSDictionary with the super properties to register.
    @param      eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
                properties that will be registered with both events and funnels.
 */
- (void)registerSuperPropertiesOnce:(CPDictionary)properties eventType:(int)eventType
{
    
}


/*!
    @method     registerSuperPropertiesOnce:defaultValue:
    @abstract   Registers a set of super properties without overwriting existing values unless the existing value is equal to defaultValue.
    @discussion Registers a set of super properties, without overwriting existing key\value pairs. If the value of an existing property is equal to defaultValue, 
                then this method will update the value of that property.  Super properties are added to all the data points.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      properties a NSDictionary with the super properties to register.
    @param      defaultValue If an existing property is equal to defaultValue, the value of said property gets updated.
 
 */
- (void)registerSuperPropertiesOnce:(CPDictionary)properties defaultValue:(id)defaultValue
{
    
}

/*!
    @method     registerSuperPropertiesOnce:eventType:defaultValue:
    @abstract   Registers a set of super properties for a specified event type without overwriting existing values unless the existing value is equal to defaultValue.
    @discussion Registers a set of super properties, without overwriting existing key\value pairs. If the value of an existing property is equal to defaultValue, 
                then this method will update the value of that property.
                Super properties are added to all the data points of the specified event type.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      properties a NSDictionary with the super properties to register.
    @param      eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
                properties that will be registered with both events and funnels.
    @param      defaultValue If an existing property is equal to defaultValue, the value of said property gets updated.

 */
- (void)registerSuperPropertiesOnce:(CPDictionary)properties eventType:(MPLibEventType)eventType defaultValue:(id)defaultValue
{
    
}

/*!
    @method     registerFunnel:steps:
    @abstract   Registers a funnel.
    @discussion Registers a funnel with an array of events to use as steps. This method simplifies funnel tracking by preregistering 
                a funnel. After calling this method, you can track funnels by calling the track: or track:properties: methods with an event specified in steps.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      funnel The name of the funnel to register
    @param      steps An array of NSString objects with the events to use as steps for this funnel.
 */
- (void)registerFunnel:(CPString)funnel steps:(CPArray)steps
{
    
}

/*!
    @method     identifyUser:
    @abstract   Identifies a user.
    @discussion Identifies a user throughout an application run. By default the UDID of the device is used as an identifier.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      identity A string to use as a user identity.
 */
- (void)identifyUser:(CPString)identity
{
    [self enqueueOrDo:function()
    {
        CPLog.info("Mixpanel identity: '" + identity + "'")
        _mpmetrics.identify(identity);
    }];
}

/*!
    @method     track:
    @abstract   Tracks an event.
    @discussion Tracks an event. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeEvent</code> get attached to events.
                If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      event The event to track.
 */
- (void)track:(CPString)event
{
    [self track:event properties:nil];
}

/*!
    @method     track:properties:
    @abstract   Tracks an event with properties.
    @discussion Tracks an event. The properties of this event are a union of the super properties of type Super properties of type 
                <code>kMPLibEventTypeAll</code>, <code>kMPLibEventTypeEvent</code> and the <code>properties</properties> parameter. 
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      event The event to track. If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
    @param      properties The properties for this event. The keys must be NSString objects and the values should be NSString or NSNumber objects.
 */
- (void)track:(CPString)event properties:(CPDictionary)properties
{
    [self enqueueOrDo:function()
    {
        var jsProperties = nil;

        if (properties != nil)
        {
            jsProperties = [self JSObjectFromDictionary:properties];
        }
        
        _mpmetrics.track(event, jsProperties, nil);
    }];
}

/*!
    @method     trackFunnel:step:goal:
    @abstract   Tracks a funnel step. 
    @discussion Tracks a funnel step.
                The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
    @param      funnelName The name for this funnel. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeFunnel</code> get attached to events.
    @param      step The step number of the step you are tracking. Step numbers start at 1.
    @param      goal A Human readable name for this funnel step.
 */
- (void)trackFunnel:(CPString)funnelName step:(CPInteger)step goal:(CPString)goal
{
    
}

/*!
     @method     trackFunnel:step:goal:properties:
     @abstract   Tracks a funnel step with properties.
     @discussion Tracks a funnel step with properties. The properties of this funnel step are a union of the super properties of type Super properties of type 
                 The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
     <code>kMPLibEventTypeAll</code>, <code>kMPLibEventTypeFunnel</code> and the <code>properties</properties> parameter. 
     @param     funnelName The name for this funnel. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeFunnel</code> get attached to events.
     @param     step The step number of the step you are tracking. Step numbers start at 1.
     @param     goal A Human readable name for this funnel step.
     @param     properties The properties for this event. The keys must be NSString objects and the values should be NSString or NSNumber objects.
 */
- (void)trackFunnel:(CPString)funnelName step:(CPInteger)step goal:(CPString)goal properties:(CPDictionary)properties
{
    
}

/*!
    @method     flush
    @abstract   Uploads datapoints to the Mixpanel Server.
    @discussion Uploads datapoints to the Mixpanel Server.
 */
- (void)flush
{
    
}

@end