import 'package:flutter/material.dart';

class Choice {
  const Choice({this.title, this.icon, this.trailing});
  final String title;
  final IconData icon;
  final Widget trailing;
}

const List<Choice> optionMenu = <Choice>[
  Choice(title: 'Show Border', icon: Icons.directions_car),
  Choice(title: 'Search sites', icon: Icons.directions_bike),
  Choice(
      title: 'Clear map',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(
      title: 'Map Mode',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(
      title: 'Rotating Map',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(
      title: 'Hiding Menu',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(
      title: 'Timing Advance',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(
      title: 'Donate',
      icon: Icons.play_arrow,
      trailing: Icon(
        Icons.play_arrow,
        color: Colors.grey,
        size: 12,
      )),
  Choice(title: 'Developer Mode', icon: Icons.directions_bike),
  Choice(title: 'Report Problem', icon: Icons.directions_bike),
  Choice(title: 'Rate App', icon: Icons.directions_bike),
  Choice(title: 'Close App', icon: Icons.directions_bike),
];

const List<Choice> clearMap = <Choice>[
  Choice(title: 'Clear Polygons', icon: Icons.cancel),
  Choice(title: 'Reload Everything', icon: Icons.delete_forever),
];

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({Key key, this.choice}) : super(key: key);

  final Choice choice;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = Theme.of(context).textTheme.headline4;
    return Card(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(choice.icon, size: 128.0, color: textStyle.color),
            Text(choice.title, style: textStyle),
          ],
        ),
      ),
    );
  }
}
