Future<T> retry<T>({
	Future<T> Function() function,
	int numberOfRetries = 3,
	Duration delayBetweenRetries = const Duration(milliseconds: 500)
}) async {
	for (int i = 0; i < numberOfRetries; i++) {
		try {
			return await function();
		}
		catch (e) {
			print("Got error on attempt ${i + 1}/$numberOfRetries: ${e.toString()}");
		}
		await Future.delayed(delayBetweenRetries);
	}
	throw Exception("Retries exhausted");
}