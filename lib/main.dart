import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Todo List'),
    );
  }
}

class Todo {
  String task;
  bool isCompleted;

  Todo({required this.task, this.isCompleted = false});

  Map<String, dynamic> toJson() => {
        'task': task,
        'isCompleted': isCompleted,
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        task: json['task'],
        isCompleted: json['isCompleted'],
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  final List<Todo> _todos = [];
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString('todos');
    if (todosJson != null) {
      final List<dynamic> decodedTodos = jsonDecode(todosJson);
      setState(() {
        _todos.addAll(decodedTodos.map((todo) => Todo.fromJson(todo)).toList());
      });
    }
  }

  Future<void> _addTodo() async {
    if (_controller.text.isNotEmpty) {
      final newTodo = Todo(task: _controller.text);
      setState(() {
        _todos.add(newTodo);
        _listKey.currentState?.insertItem(_todos.length - 1);
        _controller.clear();
      });
      await _saveTodos();
      _animationController.forward(from: 0);
    }
  }

  Future<void> _toggleTodoCompletion(int index) async {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
    });
    await _saveTodos();
  }

  Future<void> _deleteTodo(int index) async {
    final removedTodo = _todos[index];
    setState(() {
      _todos.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildTodoItem(removedTodo, animation, index),
        duration: const Duration(milliseconds: 300),
      );
    });
    await _saveTodos();
  }

  Future<void> _clearAllTodos() async {
    setState(() {
      for (var i = _todos.length - 1; i >= 0; i--) {
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildTodoItem(_todos[i], animation, i),
          duration: const Duration(milliseconds: 300),
        );
      }
      _todos.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('todos');
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String todosJson = jsonEncode(_todos.map((todo) => todo.toJson()).toList());
    await prefs.setString('todos', todosJson);
  }

  Widget _buildTodoItem(Todo todo, Animation<double> animation, int index) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: ScaleTransition(
        scale: animation,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: todo.isCompleted ? Colors.deepPurple[100] : Colors.white,
          elevation: 6,
          shadowColor: Colors.deepPurple.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Icon(
                todo.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: Colors.deepPurple,
              ),
            ),
            title: Text(
              todo.task,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                color: todo.isCompleted
                    ? Colors.deepPurple.withOpacity(0.6)
                    : Colors.black,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deleteTodo(index),
            ),
            onTap: () => _toggleTodoCompletion(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllTodos,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Add a new task',
                labelStyle: const TextStyle(color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.deepPurple[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.deepPurple),
                  onPressed: _addTodo,
                ),
              ),
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _animationController.drive(CurveTween(curve: Curves.easeIn)),
                          child: Icon(
                            Icons.task_alt,
                            color: Colors.deepPurple.withOpacity(0.6),
                            size: 72,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks yet. Add one!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.deepPurple.withOpacity(0.8),
                              ),
                        ),
                      ],
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _todos.length,
                    itemBuilder: (context, index, animation) {
                      return _buildTodoItem(_todos[index], animation, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
