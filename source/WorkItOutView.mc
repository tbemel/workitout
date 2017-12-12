using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.System as Sys;
using Toybox.Sensor as Snsr;
using Toybox.Timer as Timer;
using Toybox.Attention as Attention; //used for vibration
using Toybox.ActivityRecording as Record; //use to log activity
using Toybox.Application as App;//used to get properties
using Toybox.Lang as Lang;

// ============= WORKIT OUT APP ================
// Release v2.3 12 Dec 2017
// 
// enable minute interval training with pause, going through several round cycle of workout
// visual view of the workout by minute, highlighting in green the rest time
// HR tracking and graphics
// customizable via settings


//### Generic variables & Functions cross classes ############################
//############################################################################
//** activity recording session object
var session = null;

//** Function to handle key input ###################
var last_key = null;
var action_string;
var behavior_string;


//** Variable to cleanly exit the app as Sys.exit() gives an error
enum {
LOAD_NORMAL,
LOAD_EXIT
}
var loadMode = LOAD_NORMAL;

//** when the app started, used as timer
// startMoment|--->timeNow()
// pauseMoment--->timeNow() when exit pause = pause time
// pauseDuration = total time on pause
// total time = timeNow()-startMoment - pauseDuration
var startMoment;
var pauseMoment;
var pauseDuration;
	
//### keep action log
function setActionString(new_string)
{
    action_string = new_string;
    Ui.requestUpdate();
}
//### keep behavior log
function setBehaviorString(new_string)
{
    behavior_string = new_string;
    Ui.requestUpdate();
}

//### Stop the recording if necessary, with option to save or discard data
//# Parameter: sessionSaveOnExit;//used to tell if you should(True) or not (false) record the session on exit
function stopRecording(sessionSaveOnExit) 
{
    if( Toybox has :ActivityRecording ) 
    {
        if((session != null) && session.isRecording() == true) 
	        {
	            session.stop(); 
	            if(sessionSaveOnExit == true) 
	            {
	            	session.save();
	        	} else 
	        	{
	        		session.discard();
	    		}
	            session = null;
        	}
    }
}//end function stopRecording

//### main view class ########################################################
//############################################################################
class WorkItOutView extends Ui.View 
{
	var string_HR;
	var HR_graph;
	var value_HR;
	var showHeart; //if true show the heart sign in false hide. use to make it blinking

    //** var HR_graph;
    var dataTimer;
    var callback;

    //** font height
    var largeFontHeight;
    var mediumFontHeight; 
    var smallFontHeight; 

	//** settings holder
    //** var exerciseArray = ["Jumping Jacks", "Wall Sit", "Push-ups", "Abs Crunch", "Setup on chair", "Squats", "Triceps dip", "Plank", "High Knee Run", "Lunge", "Push-up & Turn", "Side Plank","End"];
	var record_prop = true;
	var beep_prop = true;
	var vibrate_prop = true;
	var nrRound_prop = 2; //number of circuits of minutes to repeat
	var workoutPRound_prop = 7; //number of minutes to practice
	var exerciseTime_prop = 45; //seconds to workout
	var restTime_prop = 15; //seconds to relax
   	var workoutArray_prop = ["Jumping Jacks", "Wall Sit", "Push-ups", "Abs Crunch", "Setup on chair", "Squats", "Triceps dip", "Plank", "High Knee Run", "Lunge", "Push-up & Turn", "Side Plank","Burpee","Punch boxing","High Kicks","burpee"];
	var workoutTime = restTime_prop + exerciseTime_prop;
	var roundTime = workoutTime * workoutPRound_prop; 
	var totalTime = nrRound_prop * roundTime;
	//** vibeprofile (intensity, duration in milisec)
	var vibrateData = [
                        new Attention.VibeProfile(  25, 100 ),
                        new Attention.VibeProfile(  100, 100 ),
                        new Attention.VibeProfile(  25, 100 ),
                        new Attention.VibeProfile( 100, 100 )
                      ];
                                  
    //### Initialize ################################                  
    function initialize() 
    {
        View.initialize();
		//** get the priorities
		var app = App.getApp();
        record_prop = app.getProperty("record_prop");
        if(record_prop!=null && record_prop instanceof Number) {
        }
        beep_prop = app.getProperty("beep_prop");
        vibrate_prop = app.getProperty("vibrate_prop");
        nrRound_prop = checkpropertynumber(app.getProperty("nrround_prop"));
        workoutPRound_prop = checkpropertynumber(app.getProperty("wkpround_prop"));
		restTime_prop = checkpropertynumber(app.getProperty("resttime_prop"));
		exerciseTime_prop = checkpropertynumber(app.getProperty("extime_prop"));
		
		workoutTime = restTime_prop + exerciseTime_prop;
		roundTime = workoutTime * workoutPRound_prop; 
		totalTime = nrRound_prop * roundTime;
				
		for (var i=0; i<15; i+=1) {
			workoutArray_prop[i]=checkpropertyString(app.getProperty("workout" + (i+1) + "_prop"));
			//Sys.println("workout prop:" + workoutArray_prop[i]);
			}
	

		//## initialize the key input variable
		action_string = "ACTION_NONE";
		behavior_string = "BEHAVIOR_NONE";
		
        //** initialize the heart rate sensor & chart
        string_HR = "---";
        value_HR=0;
        showHeart = true;
        //create a new chart with 90 potential points
        HR_graph = new FilledGraph( 90 );
        callback = 0;
        //initialize heart sensor
        Snsr.setEnabledSensors( [Snsr.SENSOR_HEARTRATE] );
        //direct interuption to function onSnsr
        Snsr.enableSensorEvents( method(:onSnsr) );
        
        //** get the moment of app start to use as timer, reset the pause timer to 0
		startMoment = Time.now();
		pauseMoment = Time.now();
		pauseDuration = pauseMoment.subtract(startMoment);//= 0 but incase goes to other format
        
		//** If activity recording is available & the property setting to record activated, start recording
        if( Toybox has :ActivityRecording && record_prop == true ) 
        	{
          	if( ( session == null ) || ( session.isRecording() == false ) ) 
          		{
                session = Record.createSession({:name=>"WorkItOut", :sport=>Record.SPORT_GENERIC, :subSport=>ActivityRecording.SUB_SPORT_GENERIC });
                session.start();
            	}
 			}
	}//end function initialize

	//### function called when HR sensor changed
	function onSnsr(sensor_info)
    {
        var HR = sensor_info.heartRate;
		//not sure of use of bucket, but in sample pgm
        var bucket;
        if( sensor_info.heartRate != null )
        {
            string_HR = HR.toString();
            value_HR = HR.toNumber();
            //Add value to graph
            //HR_graph.addItem(HR);
        }
        else
        {
            string_HR = "---";
            value_HR = 0;
            showHeart = true;//if no HR, just show the heart pic all the time, no need to blink as "stopped"
        }
        Ui.requestUpdate();
    }

	//### refresh the UI each time you have a timer call back and increment count. Just FYI.
	function timerCallback() 
	{
	 	callback += 1;
	 	Ui.requestUpdate();
 	}

    //### Load your resources here ######################################
    function onLayout(dc) 
    {
        //** get font sizes
    	largeFontHeight = dc.getFontHeight(Gfx.FONT_LARGE); 
    	mediumFontHeight = dc.getFontHeight(Gfx.FONT_MEDIUM); 
    	smallFontHeight = dc.getFontHeight(Gfx.FONT_SMALL); 

        //** setLayout(Rez.Layouts.MainLayout(dc));
		dataTimer = new Timer.Timer();
        
        //** timer to 1000 mili seconds = every second
        dataTimer.start( method(:timerCallback), 1000, true );
    }

    
    //### onShow
    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() 
    {
        //if asked, exit the app, work around the bug with sys.exit()
        if (loadMode == LOAD_EXIT) 
        	{
			Ui.popView(Ui.SLIDE_RIGHT);
			} else
			{
				dataTimer.start( method(:timerCallback), 1000, true );
			}
	}

    //### Update the view #########################################
    function onUpdate(dc) {
        // Call the parent onUpdate function to redraw the layout
        //View.onUpdate(dc);
        //** get watch size
        var width = dc.getWidth();
        var height = dc.getHeight();

		
		//** screen position settings
		//		========= width Arc / radius Arc
		//		min 123 max 167	# posYMinMax
		//		|chart	| 		# posYHRTopChart
		//		| ~ ~~o	| HR	# posYHR | posXHR
		//		|  ~	|		# bottom: posYHRBottomChart
		//	__________________	# mid -10
		//		exercise text	# posYExerciseText
		//		time mm:sec		# posYTime
		//		========
        //external arc setting
	    var widthArc = 20;
		var radiusArc = width/2-widthArc/2; //as width > height, take width
	    var widthArc2 = 8;
		var radiusArc2 = width/2-widthArc + widthArc2/2;
		
		//min max should be just under the external arc. 
		//As some watch have it truncated because height < width. see where it lands.
        var posYMinMax = height/2 - radiusArc + smallFontHeight+6;
		var posYHRTopChart = posYMinMax+smallFontHeight;
		var posYHR = posYHRTopChart;
		var posXHR = width -70;
		var posYHRBottomChart = height/2 -5;
		var posYExerciseText = height/2 +2;        
		var posYSplitLine = posYHRBottomChart + 5;
		var posYTime = posYExerciseText + 2 * mediumFontHeight-5;

    	//** clear screen
		dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear(); 

		//show key pressed
		//dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);	
        //dc.drawText(width/2,posYHR,Gfx.FONT_SMALL,action_string+"-"+ behavior_string,Gfx.TEXT_JUSTIFY_CENTER);
        
		//** get heart rate & add to graph
        if (value_HR != 0) {
        	HR_graph.addItem(value_HR);
		}
		HR_graph.draw(dc, [30,posYHRTopChart], [width-80,posYHRBottomChart]);

		//** Display HR valueS
        //display HR max on top right, with small "BPM" below it
		var minHR = HR_graph.getMin();
		var maxHR = HR_graph.getMax();
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);	
        dc.drawText(posXHR,posYHR,Gfx.FONT_MEDIUM,string_HR,Gfx.TEXT_JUSTIFY_LEFT);
        //print the min / max HR
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width/2,posYMinMax,Gfx.FONT_SMALL,"min"+minHR+" max"+maxHR,Gfx.TEXT_JUSTIFY_CENTER);
		
		//** put a bar just bellow the HR chart to split the screen
		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_WHITE);
		dc.drawLine(0, posYSplitLine, width, posYSplitLine);
		        
        //draw an heart, and translate xy position to heartX, heartY, then scale
		if (showHeart) { //make the heart picture blink - show -> hide -> show
			showHeart = false;
			var scaleFactor = 3;
			var heartX= posXHR+5; 
			var heartY=posYHR+mediumFontHeight;
	       	dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
	       	//coords of a polygon to draw an heart (to save memory of a bitmap)
	       	var heartCoord = ([[1,0],[2,0],[4,2],[6,0],[7,0],[8,1],[8,2],[4,6],[0,2],[0,1]]);
	       	var heartCoordXY = new [heartCoord.size()];
	       	for (var i = 0; i < heartCoord.size(); i += 1) {
	       		heartCoordXY[i]= [heartCoord[i][0]*scaleFactor+heartX,heartCoord[i][1]*scaleFactor+heartY]; //reposition the heart pic where you want
	       	}       		
			dc.fillPolygon(heartCoordXY);
		} else {
			showHeart = true;
		}
 	
		//** PROGRESS ARCs
 		//** Workout exercise red & rest green arc
		dc.setPenWidth(widthArc);
		dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
		var exerciseRelaxAngle = 360 * exerciseTime_prop / workoutTime;
		dc.drawArc(width/2, height/2, radiusArc, dc.ARC_CLOCKWISE, convertDeg2ArcDeg(0),convertDeg2ArcDeg( exerciseRelaxAngle));

 		dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc, dc.ARC_CLOCKWISE, convertDeg2ArcDeg( exerciseRelaxAngle),convertDeg2ArcDeg(exerciseRelaxAngle + 2));

       	dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc, dc.ARC_CLOCKWISE, convertDeg2ArcDeg( exerciseRelaxAngle + 2),convertDeg2ArcDeg(0));
		
	
  		//** get time and show the seconds in a small white arc running around the watch
		//calculate total timesince start  in sec = now - startMoment
		var nowMoment = Time.now();
		var durationSec = nowMoment.subtract(startMoment);//duration = current time - time @ start
		durationSec=durationSec.subtract(pauseDuration);//remove the pause time from duration
        var totalSec = durationSec.value(); // total time from start
    	var remainingTotalSec = totalTime - totalSec;
    	var remainingWorkoutSec; 
    	var totalSecWorkout;
    	if (remainingTotalSec < 0) 
    		{
    		remainingTotalSec = 0;
    		totalSecWorkout = 0;
    		remainingWorkoutSec = 0; 
    		} else
    		{
    		totalSecWorkout = (totalSec % workoutTime).toNumber(); //modulo to get secs in workout
			remainingWorkoutSec = (workoutTime - totalSecWorkout);
    		} 

    	var min = remainingTotalSec / 60;
		var sec = remainingTotalSec % 60;
		var minWorkout = (remainingWorkoutSec / 60).toNumber();
		var secWorkout = ( remainingWorkoutSec % 60).toNumber();

        //var radAngle = ( totalSecWorkout / 60.0 - 0.25) * 2 * Math.PI;
		//var cos = Math.cos(radAngle);
        //var sin = Math.sin(radAngle);
		//var radiusTimeDisk = 8; //radius in pixel of the timedisk turning around
		//var x = cos * (height/2-radiusTimeDisk);
		//var y = sin * (height/2-radiusTimeDisk);

		//** draw external arch for total time passed. If all done, stay at 360 deg.
		var angleTotalTime = 360 * totalSec / totalTime;
		if (angleTotalTime > 359 ) 
			{
			angleTotalTime = 359;
			}
 		dc.setPenWidth(widthArc2);
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc2, dc.ARC_CLOCKWISE, convertDeg2ArcDeg(0),convertDeg2ArcDeg( angleTotalTime ));

		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc2, dc.ARC_CLOCKWISE, convertDeg2ArcDeg( angleTotalTime ),convertDeg2ArcDeg(0));

	
		//** show pointer for workout time
		// first black thicker arc - to add contrast
		var angleSecWorkout = 360 * totalSecWorkout / workoutTime;
		dc.setPenWidth(widthArc+5);
		dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc, dc.ARC_CLOCKWISE,convertDeg2ArcDeg(angleSecWorkout - 6),convertDeg2ArcDeg(angleSecWorkout + 6)); //360 deg / 60 min = 6 deg / min
		//then thiner white to show the seconds
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawArc(width/2, height/2, radiusArc, dc.ARC_CLOCKWISE,convertDeg2ArcDeg(angleSecWorkout - 4),convertDeg2ArcDeg(angleSecWorkout + 4)); //360 deg / 60 min = 6 deg / min
 		
 		//** show time min:sec on bottom
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawText(width/2,posYTime,Gfx.FONT_SMALL,minWorkout.format("%02d") + ":" + secWorkout.format("%02d") + "|" + min.format("%02d")+":"+sec.format("%02d"),Gfx.TEXT_JUSTIFY_CENTER);

        //** vibrate once when seconds =(relax)
        if (totalSec <= totalTime) 
        {
	        if (totalSecWorkout == exerciseTime_prop) 
	        {
	        	if (vibrate_prop ==  true) {
	        	    Attention.vibrate( vibrateData );
	        	    }
	        	if (beep_prop == true) {
	        		Attention.playTone( 2 );
	        		}
	        } else if (totalSecWorkout == 0)
	        // if starting the exercise, beep twice, once at 0 se, then at 1 sec
	        {
				if (vibrate_prop ==  true) {
	        	    Attention.vibrate( vibrateData );
	        	    }
	        	if (beep_prop == true) {
	        		Attention.playTone( 1 );
	        		}
	
	        } else if (totalSecWorkout == 1) 
	        {
				if (vibrate_prop ==  true) {
	        	    Attention.vibrate( vibrateData );
				}
	        }
		}        
        //show exercise to do, only if minutes < count of exercise in the array, otherwise show "well done"
		var workoutCount = (totalSec / workoutTime).toNumber();
		var workoutIndex = (workoutCount % workoutPRound_prop).toNumber();
		var nextWorkoutIndex = workoutIndex + 1;
		//if reach number of workout in a round, go back to start
		if (nextWorkoutIndex >= workoutPRound_prop) 
			{ 
			nextWorkoutIndex = 0;
			}
		
		if (totalSec < totalTime)
		{
			//if exercise time, just show the workout name
			if(totalSecWorkout <= exerciseTime_prop) 
			{
				dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);		
				// show  Round# . workout#. workout name
		        dc.drawText(width/2,posYExerciseText,Gfx.FONT_MEDIUM,(workoutCount / workoutPRound_prop + 1).toString() + "." + (workoutIndex+1).toString() + " " + workoutArray_prop[(workoutIndex)],Gfx.TEXT_JUSTIFY_CENTER);
        	} 
        	//if not yet the last resttime 
        	else if (totalSec < totalTime - restTime_prop)
        	{
				dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);		
				dc.drawText(width/2,posYExerciseText,Gfx.FONT_MEDIUM,"Rest, next is",Gfx.TEXT_JUSTIFY_CENTER);
				dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
				// show  Round# . workout#. workout name or next round
				
				dc.drawText(width/2,posYExerciseText+mediumFontHeight,Gfx.FONT_MEDIUM, ((workoutCount +1) / workoutPRound_prop + 1).toString() + "." + (nextWorkoutIndex+1).toString() + " " + workoutArray_prop[nextWorkoutIndex],Gfx.TEXT_JUSTIFY_CENTER);
			} else
			{
        		// if > workout time sec & last exercise
				dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);		
				dc.drawText(width/2,posYExerciseText,Gfx.FONT_MEDIUM,"Recovery time",Gfx.TEXT_JUSTIFY_CENTER);
				dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);		
				dc.drawText(width/2,posYExerciseText+mediumFontHeight,Gfx.FONT_MEDIUM, "Last Exercise",Gfx.TEXT_JUSTIFY_CENTER);
			}	        		
			
			        		
        } else 
        {
  				// we are done!
  				dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);		
				dc.drawText(width/2,posYExerciseText,Gfx.FONT_MEDIUM, "Completed",Gfx.TEXT_JUSTIFY_CENTER);
				dc.drawText(width/2,posYExerciseText+mediumFontHeight,Gfx.FONT_MEDIUM, "Well Done!",Gfx.TEXT_JUSTIFY_CENTER);

        }//endif
        
   }//end function onUpdate

    //### on hide
    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from memory
    function onHide() 
    {
	    dataTimer.stop();
    }
    
 }//end class WorkItOutView

//############## menu and key button handling ################################
//############################################################################
class WorkItOutDelegate extends Ui.BehaviorDelegate 
{

    function initialize() 
    {
        BehaviorDelegate.initialize();
    }
    
    //### if key pressed
    function onKey(evt)
    {
        var key = evt.getKey();
        if( key == KEY_ENTER )
        // if press enter key, show menu and take time stampt to calculate pause duration when back to app
        {
            setActionString("KEY_ENTER");
            pauseMoment = Time.now();
			Ui.pushView(new Rez.Menus.MainMenu(), new WorkItOutMenuDelegate(), Ui.SLIDE_UP);
        } else if( key == KEY_ESC )
        // if press esc key, show menu and take time stampt to calculate pause duration when back to app
        {
            setActionString("KEY_ESC");
			pauseMoment = Time.now();
			Ui.pushView(new Rez.Menus.MainMenu(), new WorkItOutMenuDelegate(), Ui.SLIDE_UP);
            if( last_key == KEY_ESC ) //if esc key pressed twice, exit
            {
                loadMode = LOAD_EXIT;//exit when refreshing
                stopRecording(true);//true = save on exit 
            }
        } 
        
        last_key = key;
        return true;
        Ui.requestUpdate();
    }

}

//################### Menu Management Class ##################################
//############################################################################
class WorkItOutMenuDelegate extends Ui.MenuInputDelegate 
{
    function initialize() 
    {
        MenuInputDelegate.initialize();
    }

    //## options de menu
    function onMenuItem(item) 
    {
    	//Menu 1 = Resume
        if (item == :item_1) 
        {
	        //calculate the pauseDuration = now()- start pause moment
	        loadMode = LOAD_NORMAL;
	        var currentTime = Time.now();
			if (pauseMoment != null) 
			{ 
				pauseDuration = pauseDuration.add(currentTime.subtract(pauseMoment));// pauseduration = pauseduration + (now-startPause)
			}
      	
        //Menu 2 = save and exit
        } else if (item == :item_2)
        {
			stopRecording(true);//true= save session on exit 
			Sys.exit();
			loadMode = LOAD_EXIT;
        //Menu 3 = discard
        } else if (item == :item_3) 
        {
			stopRecording(false);//false = discard session 
			Sys.exit();
			loadMode = LOAD_EXIT;
        }
	}
}
//############ my functions
function convertDeg2ArcDeg(deg)
	//conver a normal dial degree (12 hour = 0 deg, 3 h = 90, 6h = 180, 9h = 290) to the garmin Arc one: (12 hour = 90 deg, 3 h = 0, 6h = 270, 9h = 180)
	// garmin logic: Use drawArc() to draw an arc. 0 degree: 3 o'clock position. 90 degrees: 12 o'clock position. 180 degrees: 9 o'clock position. 270 degrees: 6 o'clock position.
	{
	var result;
	if (deg > 90) {
		result = 450 - deg;
		}
	else {
		result = 90 - deg;
		}
	return result;
	}
	
function checkpropertyString(inputProp)
	//seems there are bugs on the way garmin iQ app sends properties to the watch. 
	// need to check if null or the wrong type
	{
	var result;
	if (inputProp==null) {
		result = "empty";
		}
	else {
		result = Lang.format( "$1$" , [ inputProp ] );
		}
	return result;
	}

function checkpropertynumber(inputProp)
	//seems there are bugs on the way garmin iQ app sends properties to the watch. 
	// need to check if null or the wrong type
	{
	var result;
	if (inputProp==null) {
		result = 99;
		}
	else {
		result = inputProp.toNumber();
		}
	return result;
	}	
	