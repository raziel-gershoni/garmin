import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Touch-and-hold on a subdial opens the matching native view (faces get no plain taps); in the
// watch's face editor, a tap selects a spot and the spot being edited is handed to the editor to
// pulse.
class RingPressDelegate extends WatchUi.WatchFaceDelegate {

    var _view as HebrewFaceView;

    function initialize(view as HebrewFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var ct = target(xy[0], xy[1], System.getDeviceSettings().screenWidth);
        if (ct < 0) {
            return false;
        }
        try {
            Complications.exitTo(new Complications.Id(ct as Complications.Type));
            return true;
        } catch (e) {
            Parasha.log("open " + ct + ": " + e.getErrorMessage());
            return false;
        }
    }

    // Complication to open for a press at (x, y), or -1: the widget at that spot (SUN opens the
    // next sunrise or sunset); Empty or the centre opens nothing.
    static function target(x as Number, y as Number, width as Number) as Number {
        var place = Rings.hit(x, y, width);
        if (place == 0) {
            return -1;
        }
        var sun = Today.at(Time.now(), WatchSun.get())[2] as Array<Number>?;
        return Slots.complicationType(Slots.resolve(FaceSlots.typeOf(place), sun));
    }

    // Editor only: a tap on a subdial selects its spot.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var place = Rings.hit(xy[0], xy[1], System.getDeviceSettings().screenWidth);
        if (place == 0) {
            return false;
        }
        setSelectedComplication(place);
        return true;
    }

    // Editor only: the spot being edited, drawn on its own for the editor to pulse; the face
    // leaves it out meanwhile.
    function getComplicationDrawable(ref as WatchFaceConfig.ComplicationRef) as WatchUi.Drawable or WatchUi.ComplicationDrawableRef or Null {
        var place = ref.uniqueIdentifier;
        if (place == null || place < 1 || place > FaceSlots.COUNT) {
            Parasha.log("editor asked for spot " + place);
            return null;
        }
        _view.editing = place;
        WatchUi.requestUpdate();
        var box = Rings.box(place, System.getDeviceSettings().screenWidth);
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(box[0], box[1], box[2], box[3]);
        return new WatchUi.ComplicationDrawableRef({:drawable => new RingDrawable(_view, place, box), :boundingBox => bounds});
    }

    // Editor only: a changed choice is drawn at once; every spot shows again once a spot is no
    // longer being edited.
    function onWatchFaceConfigEdited(options as {:configId as WatchFaceConfig.Id, :type as WatchUi.WatchFaceConfigType or Null, :committed as Boolean}) as Void {
        FaceSlots.load(options[:configId] as WatchFaceConfig.Id?);
        if (options[:type] != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            _view.editing = 0;
        }
        WatchUi.requestUpdate();
    }
}
