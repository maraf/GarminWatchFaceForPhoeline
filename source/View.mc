import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

class PhoelineWatchFaceView extends WatchUi.WatchFace {
    private const STEP_RING_COLOR = Graphics.createColor(255, 252, 250, 165);

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [
            clockTime.hour.format("%02d"),
            clockTime.min.format("%02d")
        ]);

        (View.findDrawableById("TimeLabel") as Text).setText(timeString);

        View.onUpdate(dc);
        drawMetricRings(dc);
    }

    private function drawMetricRings(dc as Dc) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        dc.setPenWidth(4);

        // The outer ring is a complete daily step-goal track.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
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
        System.println("Phoeline metrics: steps=" + steps.toString() +
            " stepGoal=" + stepGoal.toString());

        var stepsProgress = steps.toFloat() / stepGoal.toFloat();
        if (stepsProgress > 1.0) {
            stepsProgress = 1.0;
        }
        if (stepsProgress > 0.0) {
            dc.setColor(STEP_RING_COLOR, STEP_RING_COLOR);
            drawProgressArc(dc, centerX, centerY, 184, stepsProgress);
        }

        // The inner ring starts at 12 o'clock and fills for the body-battery value.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.drawArc(centerX, centerY, 164, Graphics.ARC_CLOCKWISE, -90, 90);

        var bodyBattery = getBodyBattery();
        System.println("Phoeline metrics: bodyBattery=" +
            (bodyBattery == null ? "null" : bodyBattery.toString()));
        if (bodyBattery != null) {
            var bodyProgress = bodyBattery.toFloat() / 100.0;
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
            dc.drawArc(centerX, centerY, 164, Graphics.ARC_CLOCKWISE, -90, -90 + (180 * bodyProgress));
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
}
