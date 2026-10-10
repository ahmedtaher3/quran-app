import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';

class SuraViewBody extends StatelessWidget {
  const SuraViewBody({super.key, required this.suras});
  final List<Sura> suras;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemCount: suras.length,
      itemBuilder: (context, index) {
        final s = suras[index];

        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/image/5540822.jpg'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerseListView(
                    suraNumber: s.number,
                    SuraName: s.name,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // رقم السورة
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    radius: 24,
                    child: Text(
                      s.number.toString(),
                      style: TextStyle(
                        
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // النصوص
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الاسم العربي
                        Text(
                          s.name,
                          style: TextStyle(
                            
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 6),

                        // آيات + مكي/مدني
                        Row(
                          children: [
                            Text(
                              "(${s.ayahs} )",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              s.revelationType == "Meccan" ? "مكية" : "مدنية",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: s.revelationType == "Meccan"
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // الاسم الإنجليزي
                  Text(
                    s.englishName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.teal[100]
                          : Colors.teal[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
