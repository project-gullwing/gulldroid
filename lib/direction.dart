import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

typedef OnPointerInputCallback = void Function(double angleDeg, double speedDegSec);

class Direction extends StatefulWidget {
  final OnPointerInputCallback onMove;
  final Function onIdle;
  final double maxSpeedDegSec;

  Direction({Key key, @required this.onMove, @required this.onIdle, @required this.maxSpeedDegSec}) : super(key: key);

  @override
  DirectionState createState() => DirectionState();

}

class DirectionState extends State<Direction> {
  Timer _timer;
  NumberFormat _fmtAngle = new NumberFormat('###');
  NumberFormat _fmtSpeed = new NumberFormat('#.##');
  GlobalKey _keyArea = GlobalKey();

  double _margin = 30;
  double _span = 0;

  // Center coords
  double _cx = 0;
  double _cy = 0;

  // Pointer coords
  double _px = 0;
  double _py = 0;
  double _pAngleDeg = 0;
  double _pSpeedDegSec = 0;

  // Actual coords
  double _aAngleDeg = 0;
  double _aSpeedDegSec = 0;
  double _ax = 0;
  double _ay = 0;


  // Control state
  bool _dragging = false;
  bool _pMove = false;
  bool _pIdle = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    _timer = Timer.periodic(Duration(milliseconds: 250), _onTick);
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    print('Disposed');
    super.dispose();
  }

  void setActualDynamicParams(double actualAngleDeg, double actualSpeedDegSec) {
    final hypotenuse = (actualSpeedDegSec / widget.maxSpeedDegSec) * _span;
    final angleRad = actualAngleDeg / 180 * pi;
    _aAngleDeg = actualAngleDeg;
    _aSpeedDegSec = actualSpeedDegSec;
    _ax = _cx + cos(angleRad) * hypotenuse;
    _ay = _cy - sin(angleRad) * hypotenuse;
  }

  void _afterLayout(_) {
    _getSizes();
  }

  void _onTick(Timer timer) {
    if (_pIdle && (null != widget.onIdle)) {
      _pIdle = false;
      _pMove = false;
      widget.onIdle();
    } else if (_pMove && (null != widget.onMove)) {
      _pMove = false;
      widget.onMove(_pAngleDeg, _pSpeedDegSec);
    }
  }

  void _updatePointerCoords(double x, double y) {
    var dx = x - _cx;
    var dy = _cy - y;
//    if (dx > _span) {
//      dx = _span;
//    }
//    if (dy > _span) {
//      dy = _span;
//    }
    final hypotenuse = sqrt(dx * dx + dy * dy);
    final r = dx / hypotenuse;
    final angle = acos(r) * ((dy > 0) ? 1 : -1);
//    if (hypotenuse > _span) {
//      x = _cx + cos(angle) * _span;
//      y = _cy - sin(angle) * _span;
//    }
    _px = x;
    _py = y;
    _pAngleDeg = angle / pi * 180;
//    _pSpeedDegSec = ((hypotenuse > _span) ? _span : hypotenuse) / _span * widget.maxSpeedDegSec;
    _pSpeedDegSec = hypotenuse / _span * widget.maxSpeedDegSec;
    _pMove = true;
  }

  void _startDrag(double x, double y) {
    setState(() {
      _updatePointerCoords(x, y);
      _dragging = true;
    });
  }

  void _updateDrag(double x, double y) {
    setState(() {
      _updatePointerCoords(x, y);
    });
  }

  void _endDrag() {
    setState(() {
      _dragging = false;
      _pIdle = true;
    });
  }

  void _getSizes() {
    final RenderBox renderBox = _keyArea.currentContext.findRenderObject();
    final sizeArea = renderBox.size;
    setState(() {
      _cx = sizeArea.width * 0.5;
      _cy = sizeArea.height * 0.5;
      _ax = _cx;
      _ay = _cy;
      _span = _cx - _margin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.center,
        child: Container(
          child: AspectRatio(
              key: _keyArea,
              aspectRatio: 1,
              child: GestureDetector(
                  onPanStart: (details) {
                    _startDrag(details.localPosition.dx, details.localPosition.dy);
                  },
                  onPanUpdate: (details) {
                    _updateDrag(details.localPosition.dx, details.localPosition.dy);
                  },
                  onPanEnd: (details) {
                    _endDrag();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.all(_margin),
                        child: SvgPicture.asset(
                          'assets/crosshair.svg',
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                      Positioned(
                          left: _ax - _margin,
                          top: _ay - _margin,
                          width: 2 * _margin,
                          height: 2 * _margin,
                          child: Visibility(
                              visible: true,
                              child: Opacity(
                                  opacity: 0.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  )))),
                      AnimatedPositioned(
                          left: ((_pAngleDeg.abs() > 140) ? _ax - 20 : _ax - 70),
                          top: ((_pAngleDeg.abs() > 140) ? _ay - 80 : _ay - 20),
                          duration: Duration(milliseconds: 100),
                          child: AnimatedOpacity(
                              opacity: _aSpeedDegSec > 0 ? 0.75 : 0,
                              duration: Duration(milliseconds: 500),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                      '${_fmtAngle.format(_aAngleDeg)}°',
                                      style: TextStyle(color: Colors.lightBlueAccent)
                                  ),
                                  Text(
                                      '${_fmtSpeed.format(_aSpeedDegSec)}°/s',
                                      style: TextStyle(color: Colors.lightBlueAccent)
                                  )
                                ],
                              ))),
                      Positioned(
                          left: _px - _margin,
                          top: _py - _margin,
                          width: 2 * _margin,
                          height: 2 * _margin,
                          child: AnimatedOpacity(
                              opacity: _dragging ? 0.75 : 0,
                              duration: Duration(milliseconds: 500),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ))),
                      AnimatedPositioned(
                          left: ((_pAngleDeg.abs() > 140) ? _px - 20 : _px - 70),
                          top: ((_pAngleDeg.abs() > 140) ? _py - 80 : _py - 20),
                          duration: Duration(milliseconds: 100),
                          child: AnimatedOpacity(
                              opacity: _dragging ? 0.75 : 0,
                              duration: Duration(milliseconds: 500),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                      '${_fmtAngle.format(_pAngleDeg)}°'
                                  ),
                                  Text(
                                      '${_fmtSpeed.format(_pSpeedDegSec)}°/s'
                                  )],
                              ))),
                    ],
                  ))),
        ));
  }
}
