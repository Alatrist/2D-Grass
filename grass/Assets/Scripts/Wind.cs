using System;
using UnityEngine;


public class Wind
{
    public static Wind Instance
    {
        get
        {
            if (instance == null)
                instance = new Wind();
            return instance;
        }
    }


    private static Wind instance;

    public Vector2 WindDir
    {
        get { return _windDir; }
        set { wind_strength = value.magnitude; _windDir = value.normalized; }
    }

    public float WhirlingSpeed = 0.5f;
    private Vector2 _windDir = new Vector2(1, 0);

    public float wind_strength { get; private set; } = 1;

}
