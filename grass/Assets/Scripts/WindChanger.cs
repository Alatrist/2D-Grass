using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WindChanger : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        var sr = GetComponent<SpriteRenderer>();
        if (sr != null)
            material = sr.material;
    }

    // Update is called once per frame
    void Update()
    {
        if (!Pause)
        {
            material.SetFloat("u_time", Time.time * timeScale);
        }
        
    }
    Material material;
    public bool Pause = false;
    public float timeScale = 1;
}
