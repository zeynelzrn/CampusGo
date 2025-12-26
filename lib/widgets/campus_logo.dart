import 'package:flutter/material.dart';

class CampusGoLogo extends StatelessWidget {
  final double size;

  const CampusGoLogo({
    Key? key,
    this.size = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/campus_go_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Color(0xFFFF2C60),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'CG',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
