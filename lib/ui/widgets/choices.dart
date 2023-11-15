// import 'package:flutter/material.dart';
//
// class Choice {
//   const Choice({this.title, this.icon, this.trailing});
//
//   final String title;
//   final IconData icon;
//   final Widget trailing;
// }
//
// const List<Choice> optionMenu = <Choice>[
//   Choice(title: 'Show Border', icon: Icons.border_outer),
//   Choice(title: 'Search Sites', icon: Icons.search),
//   Choice(title: 'Reload Everything', icon: Icons.cleaning_services),
//   Choice(title: 'Map Mode', icon: Icons.map),
//   Choice(title: 'Rotating Map', icon: Icons.threed_rotation),
//   Choice(title: 'Hiding Menu', icon: Icons.border_all),
//   Choice(title: 'Developer Mode', icon: Icons.developer_mode),
//   Choice(title: 'Report Problem', icon: Icons.report),
//   Choice(title: 'Close App', icon: Icons.close),
// ];
//
// class ChoiceCard extends StatelessWidget {
//   const ChoiceCard({Key key, this.choice}) : super(key: key);
//
//   final Choice choice;
//
//   @override
//   Widget build(BuildContext context) {
//     final TextStyle textStyle = Theme.of(context).textTheme.headline4;
//     return Card(
//       color: Colors.white,
//       child: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: <Widget>[
//             Icon(choice.icon, size: 128.0, color: textStyle.color),
//             Text(choice.title, style: textStyle),
//           ],
//         ),
//       ),
//     );
//   }
// }
