import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/learning_fact.dart';
import '../services/app_controller.dart';
import '../widgets/check_session_widgets.dart';

class TopicCheckScreen extends StatefulWidget {
  const TopicCheckScreen({
    super.key,
    required this.controller,
    required this.topicId,
  });

  final AppController controller;
  final String topicId;

  @override
  State<TopicCheckScreen> createState() => _TopicCheckScreenState();
}

class _TopicCheckScreenState extends State<TopicCheckScreen> {
  late List<String> _factIds;
  final Map<String, TextEditingController> _recallControllers = {};
  final Set<String> _difficultFactIds = {};
  var _currentIndex = 0;
  var _revealed = false;
  var _saving = false;
  var _rememberedCount = 0;
  var _difficultCount = 0;

  @override
  void initState() {
    super.initState();
    _factIds = widget.controller
        .factsForTopic(widget.topicId)
        .map((fact) => fact.id)
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final controller in _recallControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final strings = AppStrings(
          widget.controller.settings.interfaceLanguage!,
        );
        final topic = widget.controller.topics
            .where((candidate) => candidate.id == widget.topicId)
            .firstOrNull;
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.checkTab)),
            body: Center(child: Text(strings.topicDeleted)),
          );
        }

        final factsById = <String, LearningFact>{
          for (final fact in widget.controller.factsForTopic(topic.id))
            fact.id: fact,
        };
        _factIds = _factIds
            .where(factsById.containsKey)
            .toList(growable: false);
        if (_factIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(topic.title)),
            body: Center(child: Text(strings.noFactsAvailable)),
          );
        }

        final complete = _currentIndex >= _factIds.length;
        return Scaffold(
          appBar: AppBar(title: Text(topic.title)),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: complete
                  ? ListView(
                      key: const ValueKey('checkComplete'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        CheckSessionSummary(
                          title: strings.reviewComplete,
                          checkedLabel: strings.checkedFacts(_factIds.length),
                          rememberedLabel: strings.rememberedFacts(
                            _rememberedCount,
                          ),
                          difficultLabel: strings.difficultFacts(
                            _difficultCount,
                          ),
                          returnLabel: strings.returnToTopics,
                          reviewDifficultLabel: strings.reviewDifficultAgain,
                          hasDifficultFacts: _difficultFactIds.isNotEmpty,
                          onReturn: () => Navigator.of(context).pop(),
                          onReviewDifficult: _reviewDifficultFacts,
                        ),
                      ],
                    )
                  : _buildRecallStep(
                      context,
                      strings,
                      factsById[_factIds[_currentIndex]]!,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecallStep(
    BuildContext context,
    AppStrings strings,
    LearningFact fact,
  ) {
    final recallController = _recallControllers.putIfAbsent(
      fact.id,
      TextEditingController.new,
    );
    return ListView(
      key: ValueKey('checkFact-${fact.id}-$_revealed'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: (_currentIndex + (_revealed ? .5 : 0)) / _factIds.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strings.factPosition(_currentIndex + 1, _factIds.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          strings.recallInstruction,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        RecallInputCard(
          label: strings.whatYouRemembered,
          hint: strings.recallHint,
          controller: recallController,
          readOnly: _revealed,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: _revealed
              ? Column(
                  key: const ValueKey('revealedFact'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OriginalFactCard(
                      label: strings.originalFact,
                      title: fact.title,
                      body: fact.body,
                    ),
                    const SizedBox(height: 12),
                    ReviewResultButtons(
                      rememberedLabel: strings.rememberedIt,
                      reviewAgainLabel: strings.reviewAgain,
                      onRemembered: _saving
                          ? () {}
                          : () => _saveResult(
                              fact,
                              recallController.text,
                              ReviewResult.remembered,
                            ),
                      onReviewAgain: _saving
                          ? () {}
                          : () => _saveResult(
                              fact,
                              recallController.text,
                              ReviewResult.reviewAgain,
                            ),
                    ),
                  ],
                )
              : SizedBox(
                  key: const ValueKey('showFactAction'),
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('showFactButton'),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _revealed = true);
                      widget.controller.markFactRead(fact.id);
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(strings.showFact),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _saveResult(
    LearningFact fact,
    String recallText,
    ReviewResult result,
  ) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    await widget.controller.saveFactReview(
      factId: fact.id,
      recallText: recallText,
      result: result,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (result == ReviewResult.remembered) {
        _rememberedCount += 1;
        _difficultFactIds.remove(fact.id);
      } else {
        _difficultCount += 1;
        _difficultFactIds.add(fact.id);
      }
      _currentIndex += 1;
      _revealed = false;
    });
  }

  void _reviewDifficultFacts() {
    setState(() {
      _factIds = _difficultFactIds.toList(growable: false);
      _difficultFactIds.clear();
      _currentIndex = 0;
      _rememberedCount = 0;
      _difficultCount = 0;
      _revealed = false;
    });
  }
}
