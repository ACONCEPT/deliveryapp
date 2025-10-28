import 'package:flutter/material.dart';
import '../models/restaurant.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String token;
  final Restaurant restaurant;

  const RestaurantDetailScreen({
    super.key,
    required this.token,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRestaurantImage(),
            _buildRestaurantDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantImage() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 80,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildRestaurantDetails() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant name with status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (widget.restaurant.description != null &&
                widget.restaurant.description!.isNotEmpty) ...[
              Text(
                widget.restaurant.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const Divider(height: 24),
            ],

            // Phone number
            if (widget.restaurant.phone != null &&
                widget.restaurant.phone!.isNotEmpty)
              _buildInfoRow(
                icon: Icons.phone,
                label: 'Phone',
                value: widget.restaurant.phone!,
              ),

            // Full address
            if (widget.restaurant.fullAddress.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.location_on,
                label: 'Address',
                value: widget.restaurant.fullAddress,
              ),
            ],

            const Divider(height: 24),

            // Rating and total orders
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.star,
                    iconColor: Colors.amber,
                    label: 'Rating',
                    value: widget.restaurant.rating.toStringAsFixed(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_bag,
                    iconColor: Colors.blue,
                    label: 'Total Orders',
                    value: widget.restaurant.totalOrders.toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.restaurant.isActive ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.restaurant.isActive ? 'Active' : 'Inactive',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
