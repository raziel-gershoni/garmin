import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// One spot's subdial as a Drawable, for the watch's face editor to pulse while that spot is
// being edited (the face itself leaves the spot out meanwhile).
class RingDrawable extends WatchUi.Drawable {

    var _view as HebrewFaceView;
    var _place as Number;

    function initialize(view as HebrewFaceView, place as Number, box as Array<Number>) {
        Drawable.initialize({:locX => box[0], :locY => box[1], :width => box[2], :height => box[3]});
        _view = view;
        _place = place;
    }

    // The editor's dc shares the screen's origin, so the subdial draws at its usual place.
    function draw(dc as Dc) as Void {
        dc.setAntiAlias(true);
        _view.drawSlot(dc, _place, _view.lastSun(), System.getDeviceSettings().screenWidth, [0, 0], false);
    }
}
