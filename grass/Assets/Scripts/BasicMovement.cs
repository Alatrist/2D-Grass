using UnityEngine;
using System.Collections;

public class BasicMovement : MonoBehaviour, IGrassCollider
{

    public float speed;                

    private Rigidbody2D rb2d;

    public float Radius => radius;

    public float radius = 1;
    public float YOffset = 0.5f;
    public Vector2 Position => transform.position;

    // Use this for initialization
    void Start()
    {
        rb2d = GetComponent<Rigidbody2D>();
    }

    void FixedUpdate()
    {
        float moveHorizontal = Input.GetAxis("Horizontal");
        float moveVertical = Input.GetAxis("Vertical");

        Vector2 movement = new Vector2(moveHorizontal, moveVertical);

        rb2d.AddForce(movement * speed);

        var pos = transform.position;
        pos.z = (pos.y - YOffset) / 100f ;
        transform.position = pos;
    }
}
