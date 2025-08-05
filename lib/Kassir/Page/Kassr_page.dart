import 'package:flutter/material.dart';

import '../../Controller/usersCOntroller.dart';


class Kassr_Page extends StatefulWidget {

  final User user;

  const Kassr_Page({Key? key, required this.user}) : super(key: key);
  @override
  State<Kassr_Page> createState() => _Kassr_PageState();
}
v
class _Kassr_PageState extends State<Kassr_Page> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Zakazlar')),
        body: Row(
          children: [
            // Yon oyna (Sidebar)
            Container(
              width: 200,
              color: Colors.grey[300],
              child: Column(
                children: [
                  ElevatedButton(onPressed: () {}, child: Text('Открыть счет 2')),
                  ElevatedButton(onPressed: () {}, child: Text('Закрыть счет 0')),
                  Expanded(child: Container()), // Bo'sh joy qo'shish
                ],
              ),
            ),
            // Asosiy qism
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Table(
                          border: TableBorder.all(),
                          columnWidths: {
                            0: FixedColumnWidth(100),
                            1: FixedColumnWidth(80),
                            2: FixedColumnWidth(80),
                            3: FixedColumnWidth(100),
                            4: FixedColumnWidth(80),
                            5: FixedColumnWidth(80),
                          },
                          children: [
                            TableRow(
                              children: [
                                Text('Дата ОТК/Дата ЗАК'),
                                Text('№'),
                                Text('Официант'),
                                Text('Зал'),
                                Text('Сумма ВД'),
                                Text('Итого'),
                              ],
                            ),
                            TableRow(
                              children: [
                                Text('05.08 19:07'),
                                Text('#102'),
                                Text('bekzod'),
                                Text('Stol: 3'),
                                Text('24,000'),
                                Text('24,000 Yangi'),
                              ],
                            ),
                            TableRow(
                              children: [
                                Text('05.08 18:57'),
                                Text('#041'),
                                Text('bekzod'),
                                Text('Stol: 4'),
                                Text('80,000'),
                                Text('80,000 Yangi'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: () {}, child: Text('Плеать')),
                        ElevatedButton(onPressed: () {}, child: Text('Удалить')),
                        ElevatedButton(onPressed: () {}, child: Text('Закрыть счет')),
                        ElevatedButton(onPressed: () {}, child: Text('Назад')),
                        ElevatedButton(onPressed: () {}, child: Text('Выход')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}