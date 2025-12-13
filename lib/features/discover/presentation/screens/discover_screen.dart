import 'package:flutter/material.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(5),
          ),
          child: const TextField(
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search",
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 15),
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          // Banner Carousel
          _buildBannerCarousel(),

          const SizedBox(height: 20),

          // Trending Hashtags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: const Text(
              "Trending",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTrendingTags(),

          const SizedBox(height: 20),

          // Explore Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: const Text(
              "Explore",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildExploreGrid(),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 150,
      child: PageView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: [Colors.purple, Colors.blue, Colors.orange][index],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                "Banner ${index + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingTags() {
    final tags = ["#Dance", "#Comedy", "#Flutter", "#Coding", "#Viral"];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[800]!),
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey[900],
            ),
            child: Center(
              child: Text(
                tags[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7, // Portrait Aspect Ratio
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[800],
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder Image
              Image.network(
                "https://picsum.photos/seed/$index/200/300",
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
              // Likes Overlay
              const Positioned(
                bottom: 5,
                left: 5,
                child: Row(
                  children: [
                    Icon(
                      Icons.play_arrow_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 2),
                    Text(
                      "5.2k",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
