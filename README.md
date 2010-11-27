Included are two classes you might find useful when integrating Mixpanel into your Cappuccino project.

### Adding to your project

    git submodule add git://github.com/fpotter/mixpanel-cappuccino.git Frameworks/Mixpanel

# MixpanelAPI.j

This is a light wrapper on top of Mixpanel's regular Javascript API to make it more Cocoa-like.  It also handles loading the Mixpanel Javascript files for you so all you have to do is @import.  That's about it.

## Usage

Import...

    @import <Mixpanel/MixpanelAPI.j>

In `applicationDidFinishLaunching`, initialize with your project token...

    [MixpanelAPI sharedAPIWithToken:"your_project_token"];

And, log events...    

    [[MixpanelAPI sharedAPI] track:@"event1"];
    
    [[MixpanelAPI sharedAPI] track:@"event2" properties:[CPDictionary dictionaryWithObjectsAndKeys:
                                                                       "some-value",
                                                                       "some-key"]];

# MixpanelChart.j

MixpanelChart makes embedding charts using Mixpanel's new [platform](http://mixpanel.com/api/docs/guides/platform) much easier inside of Cappuccino.  It encapsulates the chart inside of a regular CPView and provides indicators for loading and no data conditions.  It also handles loading the required Javascript files.

## Usage

Import...

    @import <Mixpanel/MixpanelChart.j>

And, to create a chart...

    var chart = [[MixpanelChart alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
    
    [chart setApiKey:"your-mixpanel-api-key"];
    [chart setBucketSecret:"your-mixpanel-bucket-secret"];
    [chart setBucket:"your-bucket"];
    
    [chart setChartType:MixpanelLineChart];
    [chart setEvents:["event1", "event2"]];
    [chart setOptions:{
        mapping : { "event1" : "Event #1", "event2" : "Event #2" }
    }];
    
    [view addSubview:chart];
