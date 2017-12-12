// Class to draw a filled chart with an array of value provided. 
// enhancement based on the code of the sample app "Sensor" > class "LineGraph" from Garmin.
//---------
// Key user stories:
//- build an array of values with incremental input. 
//- calculate the max / min of all the values to scale the chart and fit a given sizing
//- plot the chart as filled polygon
//- have a maximum number of entries for system performance

using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;


//Filled graph class
class FilledGraph
{
    hidden var graphArray;
    hidden var graphIndex; //where the current point is 
    hidden var graphMin; //max value of array
    hidden var graphMax; //min value of array
	hidden var indexMin; //position of last Min found. if same as current position in array, need to recalculate min
	hidden var indexMax;
	hidden var indexMaxReached;//tell if the index when adding new item reached the end. used when calculating ratio X of graph to use max of it. 
    //! Constructor
    function initialize( size)
    {
        graphIndex = 0;
        if( size < 2 )
        {
            Sys.error( "graph size less than 2 is not allowed" );
        }
        graphArray = new [size];
	    graphMin = 0;
	    graphMax = 0;
	    indexMin = 0;
	    indexMax = 0;
	    indexMaxReached = false;//end not yet reach as starting
    }
    
    function getMin() {
    	return graphMin;
    	}
    	
	function getMax() {
    	return graphMax;
    	}
    

    function addItem(value)
    //add item only if number/float
	// check if > max or < min and update accordingly
	// check if number of entry > maxentry
    {
		//only import number or float and value is not 0
        if( value instanceof Number || value instanceof Float) {
			//Fill in new Graph value
            graphArray[graphIndex] = value.toNumber();
            //Increment and wrap graph index
            graphIndex += 1;
            //if number of item reach the size, start from beginning of array
            if( graphIndex > graphArray.size() -1 ) {
                graphIndex = 0;  
                indexMaxReached = true;//tell that you once reached the end of array when filling it
            }
        	
            // if max/ min empty, save as min and max
            if( (graphMax == 0 || graphMin==0) && value !=0 ) {
                graphMax = value;
                graphMin = value;
                indexMax = graphIndex;
                indexMin = graphIndex;
            //} else if (( graphIndex == indexMax) || (graphIndex == indexMin)){
            //check if last max/min was in new index slot, if yes, need to look for new min max
			//	lookforMinMax();
			} else if( value <= graphMin ) {
            // Save value if it is a new minimum or a new maximum, if neither, recalculate
                graphMin = value;
                indexMin = graphIndex;
            } else if (value >=  graphMax) {
            	graphMax = value;
            	indexMax = graphIndex;
            }
       }//end if   
      }//end of addItem function

    //draw the chart
    function draw(dc, topLeft, bottomRight) {
    //logic:
	// + max [at topleft [x1,y1]]
	//
	//  O value =  [ xi, yi] with 	yi = y2 - (value - min) / (max-min) * (y2-y1) = y2 - (value-min)* drawRatioY = y2 - (value-min) * (y2-y1)/(nax-min)
	//								xi = X1 + (x2-x1) * i/arraySize = x1 + i * drawRatioX = x1 + i * (x2-x1)/arraySize
	//
	// + min 					[at bottomright [x2,y2]]
        if ((graphMax != null) && (graphMin != null) && (graphArray.size()>0)) {
	        var x1 = topLeft[0];
	        var y1 = topLeft[1];
	        var x2 = bottomRight[0];
	        var y2 = bottomRight[1];

			//precalculate the drawing scaling ratio to optimize array loop calculation
			var drawRatioY = 0;
			if (graphMax != graphMin) {
				drawRatioY = 1.0f * (y2 -y1) / (graphMax - graphMin);
			} 
			var drawRatioX = 1.0f * (x2 -x1) / graphArray.size();
			var coords;
			coords = new [graphArray.size()]; //list of points 
			
			//loop through array & calculate each point coords by scaling with ratio
			var i;
			var index=graphIndex;//position to start as the index
			var resultX=1.0f;
			var resultY=1.0f;
			for( i = 0 ; i < graphArray.size() ; i += 1 ) {
				//if the array is not filled, put value on bottom, if not make the heith proportional to graphArray[index]
				if (graphArray[index] !=null) {
					resultX = x1 + i *drawRatioX; 
					resultY = y2 - (graphArray[index]-graphMin)*drawRatioY;
				} else {
					resultX = x1 + i *drawRatioX;
					resultY = y2;
				}
				coords[i] = [ resultX.toNumber(), resultY.toNumber()];
				index +=1; //move to next item and if reach end, start from start
				if (index == graphArray.size()) {
					index = 0;
					}
	        }
	
	        // Draw the chart
			dc.setColor(Gfx.COLOR_BLUE,Gfx.COLOR_BLACK);
			dc.setPenWidth(1); 
			var j = 0;
			for (j = 1; j < graphArray.size(); j+=1){
				dc.drawLine(coords[j][0],y2+1,coords[j][0],coords[j][1]);//put vertical bar lines
			}
			dc.setColor(Gfx.COLOR_RED,Gfx.COLOR_BLACK);
			dc.fillCircle(coords[j-1][0],coords[j-1][1], 3);
			
					} // endif
	} //end of function
		
		      
} //end of class

