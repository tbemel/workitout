using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class WorkItOutApp extends App.AppBase 
{
	var workItOutView = null;
    function initialize() 
    {
        AppBase.initialize();
    }


    //! onStart() is called on application start up
    function onStart(state) 
    {
    	//return false;
    }

    //! onStop() is called when your application is exiting
    function onStop(state) 
    {    
    	//return false;
    }

    //! Return the initial view of your application here
    function getInitialView() {
        if (workItOutView == null) 
        {
        	workItOutView = new WorkItOutView();
        }
        return [ workItOutView, new WorkItOutDelegate() ];
    }
  }

