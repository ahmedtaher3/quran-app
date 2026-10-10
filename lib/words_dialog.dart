import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/audio/quran_player.dart';

import 'features/Koran/data/model/word.dart';
import 'core/constants/app_constants.dart';

class WordsDialog extends StatelessWidget {
  final List<Word> words;

  const WordsDialog({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.tealSoft],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.teal.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "مفردات الآية",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                
                color: Colors.teal.shade800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "اضغط على الكلمة لسماعها ومعرفة معناها",
              style: TextStyle(
                fontSize: 14,
                color: Colors.teal.shade400,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: words.map((word) {
                    final isSpecial = word.displayMeaning.isNotEmpty;

                    return GestureDetector(
                      onTap: () {
                        // Play audio
                        if (word.audio.isNotEmpty) {
                          final url =
                              "${AppConstants.wordAudioBaseUrl}${word.audio}";
                          QuranPlayer.instance.playClip(url, title: word.text);
                        }

                        // Show meaning if it has one or if it's special
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(32)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  margin: EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Text(
                                  word.text,
                                  style: TextStyle(
                                    fontSize: 36,
                                    
                                    fontWeight: FontWeight.bold,
                                    color: isSpecial
                                        ? Colors.orange.shade900
                                        : Colors.teal.shade800,
                                  ),
                                ),
                                SizedBox(height: 16),
                                // Container(
                                //   padding: EdgeInsets.symmetric(
                                //       horizontal: 20, vertical: 12),
                                //   decoration: BoxDecoration(
                                //     color: Colors.grey.shade50,
                                //     borderRadius: BorderRadius.circular(16),
                                //   ),
                                //   child: Text(
                                //     word.translation.isNotEmpty
                                //         ? word.translation
                                //         : "لا يوجد معنى متوفر حالياً",
                                //     textAlign: TextAlign.center,
                                //     style: TextStyle(
                                //       fontSize: 18,
                                //       height: 1.6,
                                //       color: AppColors.text,
                                //     ),
                                //   ),
                                // ),
                                if (isSpecial) ...[
                                  SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome,
                                                color: Colors.orange, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              "مفردة مميزة",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.orange.shade900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          word.displayMeaning,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            height: 1.5,
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSpecial
                                        ? Colors.orange.shade700
                                        : Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    "تم استيعاب المعنى",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(height: 10),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSpecial
                              ? Colors.orange.shade100
                              : AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSpecial
                                ? Colors.orange.shade300
                                : Colors.teal.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              word.text,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                
                                color: isSpecial
                                    ? Colors.orange.shade900
                                    : AppColors.heading,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("إغلاق", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
