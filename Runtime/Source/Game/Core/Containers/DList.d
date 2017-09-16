
module Game.Core.Containers.DList;

import std.traits : hasElaborateDestructor;
import std.algorithm.mutation : moveEmplace;

import Game.Core.Memory : mallocCast, destroyFree;

struct DList(_Element)
{
@disable this(this);

alias Element = _Element;

struct Iterator
{
    private Node* node;

    ref Element value()
    {
        return node.element;
    }

    bool empty() const
    {
        return node is null;
    }

    void next()
    {
        node = node.next;
    }

    void prev()
    {
        node = node.prev;
    }
}

Iterator front()
{
    return Iterator(head);
}

Iterator insertFront(ref Element element)
{
    if(head is null)
    {
        head = tail = allocateNode();
        head.next = head.prev = null;

        moveEmplace(element, head.element);

        return Iterator(head);
    }
    else
    {
        Node* node = allocateNode();

        moveEmplace(element, node.element);

        node.next = head;
        node.prev = null;
        head.prev = node;
        head = node;

        return Iterator(node);
    }
}

Iterator insertBack(ref Element element)
{
    if(tail is null)
    {
        head = tail = allocateNode();
        head.next = head.prev = null;

        moveEmplace(element, head.element);

        return Iterator(tail);
    }
    else
    {
        Node* node = allocateNode();

        moveEmplace(element, node.element);

        node.prev = tail;
        node.next = null;
        tail.next = node;
        tail = node;

        return Iterator(node);
    }
}

Iterator insert(ref Element element, Iterator iter = Iterator())
{
    if(iter.node is null || iter.node == head)
    {
        return insertFront(element);
    }

    Node* node = allocateNode();

    moveEmplace(element, node.element);

    node.next = iter.node;
    node.prev = iter.node.prev;
    iter.node.prev = node;

    return Iterator(node);
}


void removeFront()
{
    if(head !is null)
    {
        Node* node = head;
        head = head.next;

        destroyNode(node);
    }
}

void removeBack()
{
    if(tail !is null)
    {
        Node* node = tail;
        tail = tail.next;

        destroyNode(node);
    }
}

void remove(Iterator iter)
{
    Node* node = iter.node;

    if(node is null)
    {
        return;
    }

    if(head == tail)
    {
        destroyNode(head);

        head = null;
        tail = null;

        return;
    }

    if(node == head)
    {
        head = head.next;
        head.prev = null;
    }
    else if(node == tail)
    {
        tail = tail.prev;
        tail.next = null;
    }
    else
    {
        node.next.prev = node.prev;
        node.prev.next = node.next;
    }

    destroyNode(node);
}

auto opSlice()
{
    struct Range
    {
        private Node* begin;

        void popFront()
        {
            if(begin)
            {
                begin = begin.next;
            }
        }

        ref Element front()
        {
            return begin.element;
        }

        bool empty()
        {
            return begin == null;
        }
    }

    return Range(head);
}

private:

struct Node
{
    Node* prev;
    Node* next;

    Element element;
}

Node* head;
Node* tail;

static Node* allocateNode()
{
    return mallocCast!Node(Node.sizeof);
}

static void destroyNode(Node* node)
{
    destroyFree(node);
}
}
