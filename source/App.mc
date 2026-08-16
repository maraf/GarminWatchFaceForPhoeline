import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PhoelineWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new PhoelineWatchFaceView() ];
    }
}

function getApp() as PhoelineWatchFaceApp {
    return Application.getApp() as PhoelineWatchFaceApp;
}
