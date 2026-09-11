const serviceCategories = <String, String>{
  'cleaning': 'Cleaning',
  'organizing': 'Organizing',
  'yard_work': 'Yard work',
  'repairs': 'Repairs',
  'moving': 'Moving help',
  'tutoring': 'Tutoring',
  'general': 'General',
};

String categoryLabel(String? key) {
  if (key == null) return 'Service';
  return serviceCategories[key] ?? key.replaceAll('_', ' ');
}
