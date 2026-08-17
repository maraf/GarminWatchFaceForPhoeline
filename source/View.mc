import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class PhoelineWatchFaceView extends WatchUi.WatchFace {
    private const STEP_RING_COLOR = Graphics.createColor(255, 252, 250, 165);
    private const BODY_BATTERY_RING_COLOR = Graphics.createColor(255, 114, 199, 255);
    private const CALORIES_COLOR = Graphics.createColor(255, 255, 179, 107);
    private const TIME_FILL_COLOR = STEP_RING_COLOR;
    private const TIME_OUTLINE_COLOR = Graphics.createColor(255, 22, 57, 63);
    private var _background as BitmapResource?;
    private var _weatherIcon as BitmapResource?;
    private var _caloriesIcon as BitmapResource?;
    private var _activityIcon as BitmapResource?;
    private var _stepsIcon as BitmapResource?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _background = WatchUi.loadResource(Rez.Drawables.WatchFaceBackground) as BitmapResource;
        _weatherIcon = WatchUi.loadResource(Rez.Drawables.WeatherIcon) as BitmapResource;
        _caloriesIcon = WatchUi.loadResource(Rez.Drawables.CaloriesIcon) as BitmapResource;
        _activityIcon = WatchUi.loadResource(Rez.Drawables.ActivityIcon) as BitmapResource;
        _stepsIcon = WatchUi.loadResource(Rez.Drawables.StepsIcon) as BitmapResource;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_background != null) {
            dc.drawBitmap(0, 0, _background);
        }

        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [
            clockTime.hour.format("%02d"),
            clockTime.min.format("%02d")
        ]);

        drawDate(dc);
        drawTime(dc, timeString);
        drawMetricRings(dc);
        drawMetricStack(dc);
    }

    private function drawDate(dc as Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateString = info.day_of_week + " " + info.day.toString();
        drawInfoText(dc, dc.getWidth() / 2, 66, dateString, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTime(dc as Dc, timeString as String) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2 - 45;
        var justification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(TIME_OUTLINE_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX - 2, centerY, Graphics.FONT_NUMBER_MEDIUM, timeString, justification);
        dc.drawText(centerX + 2, centerY, Graphics.FONT_NUMBER_MEDIUM, timeString, justification);
        dc.drawText(centerX, centerY - 2, Graphics.FONT_NUMBER_MEDIUM, timeString, justification);
        dc.drawText(centerX, centerY + 2, Graphics.FONT_NUMBER_MEDIUM, timeString, justification);

        dc.setColor(TIME_FILL_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY, Graphics.FONT_NUMBER_MEDIUM, timeString, justification);
    }

    private function drawMetricStack(dc as Dc) as Void {
        var activityInfo = ActivityMonitor.getInfo();
        var calories = activityInfo has :calories ? activityInfo.calories : null;
        var steps = activityInfo has :steps ? activityInfo.steps : null;
        var bodyBattery = getBodyBattery();
        var temperature = getTemperature();

        var right = dc.getWidth() - 70;
        drawInfoText(dc, right, 228,
            temperature == null ? "--" : temperature.toNumber().format("%d"),
            Graphics.TEXT_JUSTIFY_RIGHT);
        drawIcon(dc, _weatherIcon, right + 4, 230);
        drawMetricText(dc, right - 16, 256,
            calories == null ? "--" : calories.toString(),
            Graphics.TEXT_JUSTIFY_RIGHT, CALORIES_COLOR);
        drawIcon(dc, _caloriesIcon, right - 12, 258);
        drawMetricText(dc, right - 32, 284,
            bodyBattery == null ? "--" : bodyBattery.toNumber().format("%d"),
            Graphics.TEXT_JUSTIFY_RIGHT, BODY_BATTERY_RING_COLOR);
        drawIcon(dc, _activityIcon, right - 28, 286);
        drawMetricText(dc, right - 48, 312,
            steps == null ? "--" : steps.toString(),
            Graphics.TEXT_JUSTIFY_RIGHT, STEP_RING_COLOR);
        drawIcon(dc, _stepsIcon, right - 44, 314);
    }

    private function drawIcon(dc as Dc, icon as BitmapResource?, x as Number, y as Number) as Void {
        if (icon != null) {
            dc.drawBitmap(x, y, icon);
        }
    }

    private function drawInfoText(dc as Dc, x as Number, y as Number,
        value as String, justification as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, value, justification);
    }

    private function drawMetricText(dc as Dc, x as Number, y as Number,
        value as String, justification as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, value, justification);
    }

    private function drawMetricRings(dc as Dc) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        dc.setPenWidth(4);

        // The outer ring is a complete daily step-goal track.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, 184, Graphics.ARC_CLOCKWISE, 0, 360);

        var activityInfo = ActivityMonitor.getInfo();
        var steps = 0;
        var stepGoal = 10000;
        if (activityInfo has :steps) {
            var currentSteps = activityInfo.steps;
            if (currentSteps != null) {
                steps = currentSteps;
            }
        }
        if (activityInfo has :stepGoal) {
            var currentStepGoal = activityInfo.stepGoal;
            if ((currentStepGoal != null) && (currentStepGoal > 0)) {
                stepGoal = currentStepGoal;
            }
        }
        var stepsProgress = steps.toFloat() / stepGoal.toFloat();
        if (stepsProgress > 1.0) {
            stepsProgress = 1.0;
        }
        if (stepsProgress > 0.0) {
            dc.setColor(STEP_RING_COLOR, STEP_RING_COLOR);
            drawProgressArc(dc, centerX, centerY, 184, stepsProgress);
        }

        // The body-battery track runs from 6 o'clock counterclockwise to 3 o'clock.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        drawBodyBatteryArc(dc, centerX, centerY, 164, 1.0);

        var bodyBattery = getBodyBattery();
        if (bodyBattery != null) {
            var bodyProgress = bodyBattery.toFloat() / 100.0;
            if (bodyProgress > 1.0) {
                bodyProgress = 1.0;
            }
            if (bodyProgress > 0.0) {
                dc.setColor(BODY_BATTERY_RING_COLOR, Graphics.COLOR_TRANSPARENT);
                drawBodyBatteryArc(dc, centerX, centerY, 164, bodyProgress);
            }
        }

    }

    private function drawProgressArc(dc as Dc, centerX as Number, centerY as Number,
        radius as Number, progress as Float) as Void {
        var pi = 3.14159265359;
        var startAngle = -pi / 2.0;
        var endAngle = startAngle + (2.0 * pi * progress);
        var segmentCount = 72;
        var previousX = centerX + radius * Math.cos(startAngle);
        var previousY = centerY + radius * Math.sin(startAngle);

        for (var i = 1; i <= segmentCount; i += 1) {
            var ratio = i.toFloat() / segmentCount.toFloat();
            var angle = startAngle + ((endAngle - startAngle) * ratio);
            var currentX = centerX + radius * Math.cos(angle);
            var currentY = centerY + radius * Math.sin(angle);
            dc.drawLine(previousX, previousY, currentX, currentY);
            previousX = currentX;
            previousY = currentY;
        }
    }

    private function drawBodyBatteryArc(dc as Dc, centerX as Number, centerY as Number,
        radius as Number, progress as Float) as Void {
        var pi = 3.14159265359;
        var startAngle = pi / 2.0;
        var endAngle = startAngle + ((3.0 * pi / 2.0) * progress);
        var segmentCount = 54;
        var previousX = centerX + radius * Math.cos(startAngle);
        var previousY = centerY + radius * Math.sin(startAngle);

        for (var i = 1; i <= segmentCount; i += 1) {
            var ratio = i.toFloat() / segmentCount.toFloat();
            var angle = startAngle + ((endAngle - startAngle) * ratio);
            var currentX = centerX + radius * Math.cos(angle);
            var currentY = centerY + radius * Math.sin(angle);
            dc.drawLine(previousX, previousY, currentX, currentY);
            previousX = currentX;
            previousY = currentY;
        }
    }

    private function getBodyBattery() as Number or Float or Null {
        if (!(Toybox has :SensorHistory) || !(Toybox.SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }

        var history = SensorHistory.getBodyBatteryHistory({});
        if (history == null) {
            return null;
        }

        var sample = history.next();
        if (sample == null || sample.data == null) {
            return null;
        }

        return sample.data;
    }

    private function getTemperature() as Number or Float or Double or Long or Null {
        if (!(Toybox has :Weather) || !(Toybox.Weather has :getCurrentConditions)) {
            return null;
        }

        var conditions = Weather.getCurrentConditions() as Weather.CurrentConditions;
        if (conditions == null) {
            return null;
        }

        return conditions.temperature;
    }
}
