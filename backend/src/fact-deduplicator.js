const stopWords = new Set([
  // English
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'because', 'been', 'being',
  'by', 'can', 'do', 'does', 'for', 'from', 'had', 'has', 'have', 'in',
  'into', 'is', 'it', 'its', 'of', 'on', 'or', 'that', 'the', 'their',
  'this', 'through', 'to', 'was', 'were', 'which', 'while', 'with',
  // Russian
  'а', 'без', 'был', 'была', 'были', 'быть', 'в', 'во', 'для', 'до',
  'его', 'ее', 'её', 'и', 'из', 'или', 'их', 'как', 'к', 'на', 'не',
  'но', 'о', 'об', 'от', 'по', 'при', 'с', 'со', 'у', 'что', 'это',
  // Kazakh
  'ал', 'арқылы', 'бұл', 'бір', 'да', 'де', 'деп', 'және', 'үшін',
  'мен', 'пен', 'себебі', 'туралы', 'сияқты',
]);

const aliases = new Map([
  ['cardiac', 'heart'],
  ['cardio', 'heart'],
  ['healing', 'regeneration'],
  ['heal', 'regeneration'],
  ['regenerate', 'regeneration'],
  ['regenerated', 'regeneration'],
  ['regenerating', 'regeneration'],
  ['regenerative', 'regeneration'],
  ['trio', 'three'],
  ['triple', 'three'],
  ['pair', 'two'],
  ['couple', 'two'],
  ['single', 'one'],
]);

const numberAliases = new Map([
  ['1', 'one'],
  ['2', 'two'],
  ['3', 'three'],
  ['4', 'four'],
  ['5', 'five'],
  ['6', 'six'],
  ['7', 'seven'],
  ['8', 'eight'],
  ['9', 'nine'],
  ['10', 'ten'],
]);

export function isDuplicateFact(candidate, existingFacts) {
  return existingFacts.some((existing) => areFactsSimilar(candidate, existing));
}

export function areFactsSimilar(first, second) {
  const firstFingerprint = factFingerprint(first.title, first.body);
  const secondFingerprint = factFingerprint(second.title, second.body);
  if (!firstFingerprint || !secondFingerprint) {
    return false;
  }
  if (firstFingerprint === secondFingerprint) {
    return true;
  }

  const firstBody = normalizeText(first.body);
  const secondBody = normalizeText(second.body);
  if (firstBody && firstBody === secondBody) {
    return true;
  }

  const firstKeyTokens = tokenSet(first.key);
  const secondKeyTokens = tokenSet(second.key);
  if (firstKeyTokens.size > 0 && secondKeyTokens.size > 0) {
    const minimumKeySize = Math.min(
      firstKeyTokens.size,
      secondKeyTokens.size,
    );
    const keyScore = containmentScore(firstKeyTokens, secondKeyTokens);
    // A provider occasionally emits a subject-only key such as "octopus".
    // Never let such an unverified key collapse unrelated claims.
    if (minimumKeySize >= 3 && keyScore >= 0.8) {
      return true;
    }
  }

  const firstTitleTokens = tokenSet(first.title);
  const secondTitleTokens = tokenSet(second.title);
  const firstBodyTokens = tokenSet(first.body);
  const secondBodyTokens = tokenSet(second.body);
  const firstAllTokens = union(firstTitleTokens, firstBodyTokens);
  const secondAllTokens = union(secondTitleTokens, secondBodyTokens);

  const bodyScore = containmentScore(firstBodyTokens, secondBodyTokens);
  const allScore = containmentScore(firstAllTokens, secondAllTokens);
  const titleScore = containmentScore(firstTitleTokens, secondTitleTokens);
  const minimumBodySize = Math.min(firstBodyTokens.size, secondBodyTokens.size);
  const minimumAllSize = Math.min(firstAllTokens.size, secondAllTokens.size);
  const minimumTitleSize = Math.min(firstTitleTokens.size, secondTitleTokens.size);

  // Short facts used to bypass the old `minSize < 6` check completely.
  if (minimumBodySize >= 3 && bodyScore >= 0.78) {
    return true;
  }
  if (minimumAllSize >= 4 && allScore >= 0.76) {
    return true;
  }
  if (minimumTitleSize >= 2 && titleScore >= 0.8 &&
      (bodyScore >= 0.4 || allScore >= 0.58)) {
    return true;
  }

  const sharedAllTokens = intersectionSize(firstAllTokens, secondAllTokens);
  const sharedNumbers = intersectionSize(
    numberTokens(firstAllTokens),
    numberTokens(secondAllTokens),
  );
  if (sharedAllTokens >= 3 && sharedNumbers > 0 &&
      (titleScore >= 0.45 || bodyScore >= 0.3)) {
    return true;
  }

  return characterNgramDice(firstBody, secondBody) >= 0.86;
}

export function factFingerprint(title, body) {
  return normalizeText(`${title ?? ''} ${body ?? ''}`);
}

export function normalizeText(value) {
  return String(value ?? '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/([a-z])['’]s\b/gu, '$1')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function tokenSet(value) {
  const tokens = normalizeText(value).split(' ').filter(Boolean);
  return new Set(
    tokens
      .map(canonicalToken)
      .filter((token) => token.length > 1 && !stopWords.has(token)),
  );
}

function canonicalToken(rawToken) {
  const number = numberAliases.get(rawToken);
  if (number) {
    return number;
  }

  const directAlias = aliases.get(rawToken);
  if (directAlias) {
    return directAlias;
  }

  let token = rawToken;
  if (/^[a-z]+$/u.test(token)) {
    if (token.length > 5 && token.endsWith('ies')) {
      token = `${token.slice(0, -3)}y`;
    } else if (token.length > 5 &&
        /(ches|shes|sses|uses|xes|zes)$/u.test(token)) {
      token = token.slice(0, -2);
    } else if (token.length > 4 && token.endsWith('s') &&
        !token.endsWith('ss')) {
      token = token.slice(0, -1);
    }
  }

  return aliases.get(token) ?? token;
}

function containmentScore(first, second) {
  const minimumSize = Math.min(first.size, second.size);
  if (minimumSize === 0) {
    return 0;
  }
  return intersectionSize(first, second) / minimumSize;
}

function intersectionSize(first, second) {
  let shared = 0;
  const [smallest, largest] = first.size <= second.size
    ? [first, second]
    : [second, first];
  for (const token of smallest) {
    if (largest.has(token)) {
      shared += 1;
    }
  }
  return shared;
}

function union(first, second) {
  return new Set([...first, ...second]);
}

function numberTokens(tokens) {
  const canonicalNumbers = new Set([
    'one', 'two', 'three', 'four', 'five',
    'six', 'seven', 'eight', 'nine', 'ten',
  ]);
  return new Set([...tokens].filter((token) => canonicalNumbers.has(token)));
}

function characterNgramDice(first, second) {
  if (first.length < 12 || second.length < 12) {
    return 0;
  }
  const firstNgrams = ngrams(first, 3);
  const secondNgrams = ngrams(second, 3);
  const denominator = firstNgrams.size + secondNgrams.size;
  return denominator === 0
    ? 0
    : (2 * intersectionSize(firstNgrams, secondNgrams)) / denominator;
}

function ngrams(value, size) {
  const compact = value.replace(/\s+/g, ' ');
  const result = new Set();
  for (let index = 0; index <= compact.length - size; index += 1) {
    result.add(compact.slice(index, index + size));
  }
  return result;
}
