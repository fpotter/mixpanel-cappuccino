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

@import <AppKit/CPTextField.j>
@import <AppKit/CPView.j>
@import <AppKit/CPProgressIndicator.j>

MixpanelLineChart = 1;
MixpanelPropertyLineChart = 2;
MixpanelPieChart = 3;
MixpanelPropertyPieChart = 4;
MixpanelBarChart = 5;
MixpanelPropertyBarChart = 6;
MixpanelStackedHistogram = 7;

var MixpanelChartJQueryIsLoaded = NO,
    MixpanelChartPlatformIsLoaded = NO,
    MixpanelChartJQueryIsLoading = NO,
    MixpanelChartPlatformIsLoading= NO;

@implementation MixpanelChart : CPView
{
    DOMElement _DOMMixpanelElement;
    
    CPString _apiKey @accessors(property = apiKey);
    CPString _bucketSecret @accessors(property = bucketSecret);
    CPString _bucket @accessors(property = bucket);
    
    
    int _chartType @accessors(property = chartType);
    
    CPArray _events @accessors(property = events);

    CPString _event @accessors(property = event);
    CPString _name @accessors(property = name);
    CPArray _values @accessors(property = values);
    
    JSObject _options @accessors(property = options);
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        _options = {};
        _events = [];
        
        [self addSubview:[self viewForLoading]];
                
        [self _DOMMixpanelElement];
    }
    return self;
}

- (CPView)viewForLoading
{
    var bounds = [self bounds];
    
    var view = [[CPView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    
    var box = [[CPBox alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    [box setBorderType:CPLineBorder];
    [box setBorderColor:[CPColor colorWithHexString:"ddd"]];
    [box setFillColor:[CPColor colorWithHexString:"fff"]];
    [box setBorderWidth:1];
    [box setCornerRadius:0]
    [view addSubview:box];
    
    var label = [CPTextField labelWithTitle:"Loading..."];
    [label setFont:[CPFont boldSystemFontOfSize:14]];
    [label setTextColor:[CPColor colorWithHexString:"555"]];
    [label sizeToFit];
    [view addSubview:label];
    
    [label setFrameOrigin:CGPointMake(bounds.size.width / 2 - [label frameSize].width,
                                      bounds.size.height / 2 - [label frameSize].height)];

    return view;
}

- (CPView)viewForNoData
{
    var bounds = [self bounds];
    
    var view = [[CPView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    
    var box = [[CPBox alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    [box setBorderType:CPLineBorder];
    [box setBorderColor:[CPColor colorWithHexString:"ddd"]];
    [box setFillColor:[CPColor colorWithHexString:"fff"]];
    [box setBorderWidth:1];
    [box setCornerRadius:0]
    [view addSubview:box];
    
    var label = [CPTextField labelWithTitle:"There's not enough data to show yet."];
    [label setFont:[CPFont boldSystemFontOfSize:14]];
    [label setTextColor:[CPColor colorWithHexString:"555"]];
    [label sizeToFit];
    [view addSubview:label];
    
    [label setFrameOrigin:CGPointMake(bounds.size.width / 2 - [label frameSize].width / 2,
                                      bounds.size.height / 2 - [label frameSize].height / 2)];

    return view;
}

- (DOMElement)_DOMMixpanelElement
{
    if (!_DOMMixpanelElement)
    {
        var bounds = [self bounds];
        
        _DOMMixpanelElement = document.createElement("div");
        _DOMMixpanelElement.style.position = @"absolute";
        _DOMMixpanelElement.style.visibility = @"hidden";
        _DOMMixpanelElement.style.background = @"none";
        _DOMMixpanelElement.style.border = @"0";
        _DOMMixpanelElement.style.outline = @"0";
        _DOMMixpanelElement.style.zIndex = @"100";
        _DOMMixpanelElement.style.padding = @"0";
        _DOMMixpanelElement.style.margin = @"0";
        _DOMMixpanelElement.style.width = bounds.size.width + "px";
        _DOMMixpanelElement.style.height = bounds.size.height + "px";
        _DOMMixpanelElement.id = "mixpanel-in-capp-" + [CPString UUID];
        
        self._DOMElement.appendChild(_DOMMixpanelElement);
    }
    
    return _DOMMixpanelElement;
}

- (void)viewWillMoveToWindow:(CPWindow)aWindow
{
    [super viewWillMoveToWindow:window];
    
    var allLoaded = YES;
    
    if (!MixpanelChartJQueryIsLoaded && !MixpanelChartJQueryIsLoading)
    {
        MixpanelChartJQueryIsLoading = YES;
        
        var url = (('https:' == document.location.protocol) ? 'https://' : 'http://') + 'ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js';
        [self loadScriptFromURL:url callback:function()
        {
            MixpanelChartJQueryIsLoading = NO;
            MixpanelChartJQueryIsLoaded = YES;

            [self onScriptLoad];
        }];
        
        allLoaded = NO;
    }
    
    if (!MixpanelChartPlatformIsLoaded && !MixpanelChartPlatformIsLoading)
    {
        MixpanelChartPlatformIsLoading = YES;
        
        var url = (('https:' == document.location.protocol) ? 'https://' : 'http://') + 'mixpanel.com/site_media/api/platform/platform.1.min.js';
        [self loadScriptFromURL:url callback:function()
        {
            MixpanelChartPlatformIsLoading = NO;
            MixpanelChartPlatformIsLoaded = YES;

            [self onScriptLoad];
        }];
        
        allLoaded = NO;
    }
    
    if (allLoaded)
    {
        [self onScriptLoad];
    }
}

- (void)loadScriptFromURL:(CPString)url callback:(JSFunction)callback
{
    var script = document.createElement("script");
    script.src = url;
    script.type = "text/javascript";
    script.charset = "UTF-8";    

    // Either one or the other of the following handlers will get
    // called, depending on the browser.
    script.onreadystatechange = function ()
    {
        if (this.readyState == 'complete')
        {
            callback();
        }
    };

    script.onload = function()
    {
        callback();
    };
    
    document.getElementsByTagName("head")[0].appendChild(script);
}

- (void)onScriptLoad
{
    if (MixpanelChartJQueryIsLoaded && MixpanelChartPlatformIsLoaded)
    {
        [self loadChart];
    }
}

- (void)loadChart
{
    var platform = new Mixpanel.Platform(
        _apiKey,
        _bucketSecret,
        _bucket
    );
    
    var containerId = [self _DOMMixpanelElement].id;

    switch (_chartType)
    {
        case MixpanelLineChart:
            platform.create_line_chart(containerId, _events, _options);
            break;
        case MixpanelPropertyLineChart:
            platform.create_property_line_chart(containerId, _event, _name, _values, _options);
            break;
        case MixpanelPieChart:
            platform.create_pie_chart(containerId, _events, _options);
            break;
        case MixpanelPropertyPieChart:
            platform.create_property_pie_chart(containerId, _event, _name, _values, _options);
            break;
        case MixpanelBarChart:
            platform.create_bar_chart(containerId, _events, _options);
            break;
        case MixpanelPropertyBarChart:
            platform.create_property_bar_chart(containerId, _event, _name, _values, _options);
            break;
        case MixpanelStackedHistogram:
            platform.create_stacked_histogram(containerId, _events, _options);
            break;
        default:
            [CPException raise:CPInternalInconsistencyException
                        reason:"Unknown chart type: " + _chartType];
    }
    
    [self waitForChartToLoad];
}

- (void)waitForChartToLoad
{
    if ($([self _DOMMixpanelElement]).children().length > 0)
    {
        [self onChartLoad];
    }
    else
    {
        // Check again in a moment
        setTimeout(function()
        {
            [self waitForChartToLoad];
        }, 100);
    }
}

- (void)onChartLoad
{
    var isEmpty = ($("defs", [self _DOMMixpanelElement]).children().length == 0);
    
    if (isEmpty)
    {
        [[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self addSubview:[self viewForNoData]];
    }
    else
    {
        [self _DOMMixpanelElement].style.visibility = "visible";
    }
}



@end