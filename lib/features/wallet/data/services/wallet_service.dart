import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';

class WalletService {
  final Dio _dio;

  WalletService({Dio? dio}) : _dio = dio ?? Dio();

  Future<double> getBalance() async {
    // Mock
    await Future.delayed(const Duration(milliseconds: 500));
    return 150.50;
  }

  Future<void> buyTokens(double amount) async {
    // Mock Buy
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  Future<void> withdraw(double amount) async {
    // Mock Withdraw
    await Future.delayed(const Duration(milliseconds: 1000));
  }
}
